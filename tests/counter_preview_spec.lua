-- Tests for the counter PREVIEW (Trait.counterPreview / Combat.previewCounters): what the hover panel
-- promises will be thrown back at you, weighed against what the live blow actually provokes.
--
-- The whole point of this preview is that it is trustworthy, so nearly every case here asserts the
-- promise and the exchange TOGETHER: preview the counter, throw the blow for real, and check the two
-- agree. A preview that merely looked plausible would be worse than none -- the player commits a turn
-- on it. It must also stay pure: reading it may not spend the defender's cooldown, stamina, or HP.
--
-- Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Trait = require("models.trait")
local Status = require("models.status")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

-- A character instance with an empty grid carrying exactly `traits`, then exactly `items` -- so a
-- fixture's reflexes are only the ones it was handed. Note the grid arms it too: an iron sword brings
-- Parry along with it (data/items/weapon/weapon_iron_sword.lua), which is how most of these fixtures get one.
local function fighter(id, traits, items)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    char.traits = traits
    for _, itemId in ipairs(items or {}) do Character.addItem(char, Item.instantiate(itemId)) end
    return char
end

-- The one counter the panel would show for `attacker` striking `target` with its default weapon, plus
-- the weapon itself -- the shape every case below opens with. Asserts a single answer, since a fixture
-- that provokes two has gone wrong somewhere other than the case under test.
local function soleCounter(c, attacker, target, opts)
    local weapon = Combat.defaultWeapon(attacker.char)
    local preview = Combat.previewAbility(c, attacker, weapon, target.x, target.y)
    local list = Combat.previewCounters(c, attacker, weapon, target,
        { entry = preview and preview.entries[target] }) or {}
    assert(#list <= 1, "fixture provokes more than one reflex: " .. #list)
    return list[1], weapon
end

return {
    {
        name = "a previewed parry names the reflex and the damage the live counter deals",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_sword" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            local knightHP = k.char.stats.health.current
            local stamina = Combat.resource(b.char, "stamina")

            local counter, weapon = soleCounter(c, k, b)
            assert(counter, "an adjacent swordsman answers a melee blow")
            assert(counter.name == "Parry", "and the panel names the reflex: " .. tostring(counter.name))
            assert(counter.damage > 0, "with the damage its weapon would land")
            assert(not counter.lethal, "which a knight at full health survives")

            -- Reading the preview must cost the defender nothing at all.
            assert(Combat.resource(b.char, "stamina") == stamina, "the preview spends no stamina")
            assert((b.answersThisRound or 0) == 0, "and does not tally as an answer thrown")
            assert(k.char.stats.health.current == knightHP, "and lands no damage")

            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "the live parry deals exactly what the panel promised")
        end,
    },
    {
        name = "a blow that fells its target is answered by nothing, and the panel says so",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_sword" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            b.char.stats.health.current = 1 -- the next hit kills, and a corpse never parries
            local knightHP = k.char.stats.health.current

            assert(soleCounter(c, k, b) == nil, "no answer is previewed for a killing blow")

            local weapon = Combat.defaultWeapon(k.char)
            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(not b.alive, "the blow fells it")
            assert(k.char.stats.health.current == knightHP, "and the dead throw nothing back")
        end,
    },
    {
        -- Stamina is the only thing that can silence a reflex now, so it is the only thing the promise
        -- has to weigh -- and it must weigh the ESCALATED price, not the base one, or the panel would
        -- promise a third answer the exchange then refuses.
        name = "a reflex that can't be paid for is never promised, at whatever the price has climbed to",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_sword" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            local swing = Combat.defaultWeapon(b.char).activeAbility.cost.amount

            b.char.stats.stamina.current = swing - 1
            assert(soleCounter(c, k, b) == nil, "an exhausted swordsman is promised no answer")

            b.char.stats.stamina.current = swing
            local promised = soleCounter(c, k, b)
            assert(promised, "with a swing's worth back, the answer is on again")
            -- A LIST of pools, since the answering weapon may draw on several (Trait.answerCost); an
            -- iron sword names exactly one, and the promise quotes it.
            assert(promised.cost and #promised.cost == 1 and promised.cost[1].amount == swing,
                "and the promise names what answering will cost")

            -- Two answers already thrown this round: the next is priced at quadruple, which this pool
            -- cannot reach even though the base price sits right there in it.
            b.answersThisRound = 2
            assert(soleCounter(c, k, b) == nil, "an answer priced beyond the pool is never promised")
            b.char.stats.stamina.current = swing * 4
            local dearer = soleCounter(c, k, b)
            assert(dearer and dearer.cost[1].amount == swing * 4, "and the promise quotes the escalated price")
        end,
    },
    {
        name = "the reach rules hold: a melee reflex is promised only from an adjacent tile",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_sword" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(8, 8), { unit(knight, 1, 1) }, { unit(bandit, 5, 1) })
            local k, b = c.units[1], c.units[2]

            assert(soleCounter(c, k, b) == nil, "a blade four tiles off answers nothing")

            -- Click-to-use walks into reach and strikes from there, so the panel must weigh the answer
            -- from the STAND tile -- the whole reason previewCounters takes one.
            local weapon = Combat.defaultWeapon(k.char)
            local list = Combat.previewCounters(c, k, weapon, b, { fromX = 4, fromY = 1 })
            assert(list and #list == 1, "walking in first provokes the parry the preview must show")
            assert(list[1].name == "Parry", "and it is named from the stand tile's distance")
            assert(k.x == 1 and k.y == 1, "weighing a blow from elsewhere never moves the attacker")
        end,
    },
    {
        name = "a riposte is previewed as turning the blow aside, and the live blow deals nothing",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_sword" })
            local duelist = fighter("character_bandit", {}, { "weapon_riposte_blade" })
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(duelist, 2, 1) })
            local k, d = c.units[1], c.units[2]
            local knightHP, duelistHP = k.char.stats.health.current, d.char.stats.health.current

            local counter, weapon = soleCounter(c, k, d)
            assert(counter, "the blade answers an adjacent blow")
            assert(counter.deflects, "and the panel flags that your blow never lands")
            assert(counter.damage > 0, "while its own does")

            Combat.useItem(c, k, weapon, d.x, d.y)
            assert(d.char.stats.health.current == duelistHP, "the riposte voids the blow entirely")
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "and answers for exactly what the panel promised")
        end,
    },
    {
        name = "Keen Senses is previewed as answering FIRST, and flags an answer that would kill",
        fn = function()
            -- A staff, not a sword: an iron sword would carry its own Parry and answer twice.
            local priest = fighter("character_priest", { "trait_keen_senses" }, { "weapon_parasitic_staff" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" })
            local c = Combat.new(arena(6, 6), { unit(bandit, 1, 1) }, { unit(priest, 2, 1) })
            local b, p = c.units[1], c.units[2]

            local counter = soleCounter(c, b, p)
            assert(counter and counter.first, "the panel flags a reflex that lands before your blow")
            assert(not counter.lethal, "a healthy attacker survives it")

            -- The one warning worth the panel's space: swing and you die before you land it.
            b.char.stats.health.current = 1
            counter = soleCounter(c, b, p)
            assert(counter and counter.lethal, "an answer that would fell the attacker is called out")
        end,
    },
    {
        name = "an ally's support cast provokes nothing, and neither does a spell on a swordsman",
        fn = function()
            local mage = fighter("character_mage", {}, { "weapon_wand" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(mage, 1, 1) }, { unit(bandit, 2, 1) })
            local m, b = c.units[1], c.units[2]

            assert(Combat.previewCounters(c, m, Combat.defaultWeapon(m.char), m, {}) == nil,
                "nothing answers a cast aimed at your own side")

            -- A parry answers the blow, not the school: a wand to the face is still a melee strike.
            local counter = soleCounter(c, m, b)
            assert(counter and counter.name == "Parry", "an adjacent swordsman answers what it can reach")
        end,
    },
    {
        name = "an AREA blow is answered by nothing -- the panel promises no parry, and none is thrown",
        fn = function()
            -- A blast is nobody's duel: it is aimed at ground, and everything standing there catches the
            -- same burst. There is no swing aimed at the swordsman to turn aside, so his Parry sleeps --
            -- which is also what keeps one bomb from being answered once per body it caught.
            local knight = fighter("character_knight", {}, { "weapon_iron_axe" }) -- axes cleave: a 3-wide arc, an AoE
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            local knightHP = k.char.stats.health.current
            local stamina = Combat.resource(b.char, "stamina")

            local counter, weapon = soleCounter(c, k, b)
            assert(counter == nil, "the panel promises no answer to a cleave")

            assert(Combat.useItem(c, k, weapon, b.x, b.y), "the arc lands")
            assert(k.char.stats.health.current == knightHP, "and nothing is thrown back at the axeman")
            assert(Combat.resource(b.char, "stamina") == stamina, "the swordsman's guard was never spent")

            -- The same swordsman still answers a blow aimed at HIM, so the case above is the blast
            -- talking and not a broken fixture.
            local sword = fighter("character_knight", {}, { "weapon_iron_sword" })
            local c2 = Combat.new(arena(6, 6), { unit(sword, 1, 1) }, { unit(fighter("character_bandit", {}, { "weapon_iron_sword" }), 2, 1) })
            assert(soleCounter(c2, c2.units[1], c2.units[2]), "a single-target blow is answered as ever")
        end,
    },
    {
        -- The reported bug: an imp spits from two tiles (Cinder Spit, range 2) and a swordsman parried
        -- it -- which a range-1 blade must never reach. Parry is the sword's own reach, so it does not;
        -- and adding a bow to the grid does not lend the blade the range either ("how can the bow
        -- parry?"). The whole point of the imp keeping its distance (weapon_cinder_spit.lua) rides on this.
        name = "a two-tile spit is beyond the blade -- neither a sword nor a sword-and-bow parries it",
        fn = function()
            for _, grid in ipairs({ { "weapon_iron_sword" }, { "weapon_iron_sword", "weapon_iron_longbow" } }) do
                local knight = fighter("character_knight", {}, grid)
                local imp = fighter("character_demon_imp", {}, {}) -- carries its Cinder Spit (range 2)
                local c = Combat.new(arena(8, 8), { unit(knight, 1, 1) }, { unit(imp, 3, 1) })
                local k, i = c.units[1], c.units[2]
                k.char.stats.health.current = 999 -- survive so the on-hit reflex is actually reached
                local impHP = i.char.stats.health.current

                assert(soleCounter(c, i, k) == nil, "the panel promises no parry to a two-tile spit")

                Combat.useItem(c, i, Combat.defaultWeapon(i.char), k.x, k.y)
                assert(i.char.stats.health.current == impHP,
                    "and none is thrown: a blade cannot answer what it cannot reach")
            end
        end,
    },
    {
        name = "counterPreview walks the same gates the live reflex does",
        fn = function()
            -- mayCounter is the single rule both the hover panel and the onDamaged hooks read, so a
            -- reflex the panel promises is one the hook fires: assert they agree unit by unit.
            local knight = fighter("character_knight", {}, { "weapon_iron_sword" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            local parry
            for _, t in ipairs(b.traits) do if t.id == "trait_parry" then parry = t end end
            assert(parry, "fixture carries the reflex under test")

            assert(Trait.mayCounter(c, b, parry, k, { "physical" }), "adjacent: the gate opens")
            b.x = 5
            assert(not Trait.mayCounter(c, b, parry, k, { "physical" }), "across the field: it shuts")
            b.x = 2
            b.side = k.side
            assert(not Trait.mayCounter(c, b, parry, k, { "physical" }), "a friendly source is never answered")
        end,
    },
    {
        -- The bug this guards: the hammer USED to stun on the line after fx.damage, which is one line
        -- too late -- the parry had already fired from inside the damage core, so the weapon whose
        -- whole point is leaving the target reeling was answered by the target it had just rattled.
        -- The stun now rides the blow (`inflicts`), landing between the wound and the on-hit hooks.
        name = "a hammer's stun rides the blow, so the reeling target never answers it",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_hammer" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            b.char.stats.health.max = 999 -- it must SURVIVE the hammer, or it proves nothing
            b.char.stats.health.current = 999
            local knightHP = k.char.stats.health.current

            assert(soleCounter(c, k, b) == nil, "no answer is promised for a blow that stuns")

            local weapon = Combat.defaultWeapon(k.char)
            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(b.char.stats.health.current < 999, "the hammer landed")
            assert(k.char.stats.health.current == knightHP,
                "and the stunned target threw nothing back, as the panel promised")
        end,
    },
    {
        -- The other half of the rule: suppression is the CARRIED status's doing, not the attacker's
        -- luck. Strip the stun off the same weapon and the same fixture answers again -- otherwise
        -- this pair would pass just as well if hammers had quietly stopped provoking anything.
        name = "the same hammer without its stun is answered normally",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_hammer" })
            local bandit = fighter("character_bandit", {}, { "weapon_iron_sword" })
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            b.char.stats.health.max = 999
            b.char.stats.health.current = 999
            local knightHP = k.char.stats.health.current

            -- A hammer that only hits: no stun rides along.
            local hammer = Combat.defaultWeapon(k.char)
            hammer.activeAbility.effect = function(fx) fx.damage(fx.target) end

            local counter = soleCounter(c, k, b)
            assert(counter and counter.name == "Parry", "an unrattled swordsman answers as usual")

            Combat.useItem(c, k, hammer, b.x, b.y)
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "and the live parry deals exactly what the panel promised")
        end,
    },
    {
        -- A riposte fires BEFORE the blow lands and negates it outright -- so the hammer never
        -- connects, never stuns, and has no standing to suppress the answer to a hit it didn't land.
        -- This is the line between the two kinds of reflex, and it is the one most likely to be
        -- broken by someone "simplifying" the suppression check upward past the pre-hit reflexes.
        name = "a riposte still turns a stunning blow aside: an unlanded hammer stuns no one",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_hammer" })
            local duelist = fighter("character_bandit", {}, { "weapon_riposte_blade" })
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(duelist, 2, 1) })
            local k, d = c.units[1], c.units[2]
            local knightHP = k.char.stats.health.current
            local duelistHP = d.char.stats.health.current

            local counter = soleCounter(c, k, d)
            assert(counter, "the blade still answers a hammer")
            assert(counter.deflects, "and the panel says it turns the blow aside")

            local weapon = Combat.defaultWeapon(k.char)
            Combat.useItem(c, k, weapon, d.x, d.y)
            assert(d.char.stats.health.current == duelistHP, "the deflected hammer deals nothing")
            assert(not Status.has(d, "status_stun"), "so it stuns no one")
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "and the riposte lands exactly what the panel promised")
        end,
    },
    {
        -- The control for the two shove cases below: with nothing displacing anyone, a brawler struck
        -- from the next tile answers. If this one ever fails, the fixture is broken and not the rule.
        name = "a brawler answers a blow struck from the tile beside it",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_sword" })
            local brawler = fighter("character_knight", { "trait_melee_counter" }, { "weapon_iron_mace" })
            local c = Combat.new(arena(6, 6), { unit(knight, 2, 1) }, { unit(brawler, 3, 1) })
            local k, b = c.units[1], c.units[2]
            local knightHP = k.char.stats.health.current

            local counter, weapon = soleCounter(c, k, b)
            assert(counter and counter.name == "Melee Counter", "the reflex answers: " .. tostring(counter and counter.name))
            assert(counter.damage > 0, "with the mace it swings back")

            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "and the live counter deals exactly what the panel promised")
        end,
    },
    {
        -- The rule this whole hold exists for: an answer belongs to the board the action LEAVES, not
        -- the one it passed through. The mace wounds and then shoves two tiles, so by the time the
        -- brawler would answer there is no one within reach of a fist -- and the panel must not have
        -- promised otherwise.
        name = "a blow that shoves its target out of melee is answered by nothing",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_mace" })
            local brawler = fighter("character_knight", { "trait_melee_counter" }, { "weapon_iron_mace" })
            local c = Combat.new(arena(6, 6), { unit(knight, 2, 1) }, { unit(brawler, 3, 1) })
            local k, b = c.units[1], c.units[2]
            local knightHP = k.char.stats.health.current

            local counter, weapon = soleCounter(c, k, b)
            assert(not counter, "the panel promises no answer the shove would carry out of range")

            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(b.x == 5 and b.y == 1, "the mace drove it two tiles back, as it should")
            assert(k.char.stats.health.current == knightHP, "and nothing answered from out there")
        end,
    },
    {
        -- ...and the other half of the same rule: a shove that goes NOWHERE changes nothing. Backed
        -- against the board edge the brawler is still standing where it was struck, so it answers --
        -- which is what keeps the fix from degrading into "a mace is never countered".
        name = "a shove barred by the board edge leaves the brawler in reach, and it answers",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_mace" })
            local brawler = fighter("character_knight", { "trait_melee_counter" }, { "weapon_iron_mace" })
            local c = Combat.new(arena(6, 6), { unit(knight, 2, 1) }, { unit(brawler, 1, 1) })
            local k, b = c.units[1], c.units[2]
            local knightHP = k.char.stats.health.current

            local counter, weapon = soleCounter(c, k, b)
            assert(counter and counter.name == "Melee Counter", "pinned against the edge, it still answers")

            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(b.x == 1 and b.y == 1, "the shove had nowhere to go")
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "so the counter lands exactly what the panel promised")
        end,
    },
    {
        -- The line the rule above is really drawn along. Thorns don't reach back for anyone -- they bite
        -- the fist at the instant it lands -- so a shove that comes AFTER the blow cannot carry their
        -- bearer out of a bite already taken. Break this and "a counter needs reach" quietly becomes
        -- "a mace is immune to armor spikes".
        name = "spikes bite the mace that shoved them: a reflecting reflex is the contact, not a swing",
        fn = function()
            local knight = fighter("character_knight", {}, { "weapon_iron_mace" })
            local thorny = fighter("character_knight", { "trait_thorns" }, { "weapon_iron_mace" })
            local c = Combat.new(arena(6, 6), { unit(knight, 2, 1) }, { unit(thorny, 3, 1) })
            local k, b = c.units[1], c.units[2]
            local knightHP = k.char.stats.health.current

            local counter, weapon = soleCounter(c, k, b)
            assert(counter and counter.name == "Thorns", "the panel promises the bite: " .. tostring(counter and counter.name))
            assert(counter.damage > 0, "with a share of the blow thrown back")

            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(b.x == 5 and b.y == 1, "the mace still drove it two tiles back")
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "and the spikes still bit for exactly what the panel promised")
        end,
    },
}
