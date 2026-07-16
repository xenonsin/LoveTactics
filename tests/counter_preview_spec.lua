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
-- Parry along with it (data/items/weapon/iron_sword.lua), which is how most of these fixtures get one.
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
            local knight = fighter("knight", {}, { "iron_sword" })
            local bandit = fighter("bandit", {}, { "iron_sword" }) -- the sword carries Parry
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
            assert(not Combat.onCooldown(b, "parry"), "and burns no cooldown")
            assert(k.char.stats.health.current == knightHP, "and lands no damage")

            Combat.useItem(c, k, weapon, b.x, b.y)
            assert(knightHP - k.char.stats.health.current == counter.damage,
                "the live parry deals exactly what the panel promised")
        end,
    },
    {
        name = "a blow that fells its target is answered by nothing, and the panel says so",
        fn = function()
            local knight = fighter("knight", {}, { "iron_sword" })
            local bandit = fighter("bandit", {}, { "iron_sword" }) -- the sword carries Parry
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
        name = "a reflex that can't be paid for, or is still recharging, is never promised",
        fn = function()
            local knight = fighter("knight", {}, { "iron_sword" })
            local bandit = fighter("bandit", {}, { "iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]

            b.char.stats.stamina.current = 3 -- one short of a parry's 4
            assert(soleCounter(c, k, b) == nil, "an exhausted swordsman is promised no answer")

            b.char.stats.stamina.current = 40
            assert(soleCounter(c, k, b), "with stamina back, the answer is on again")

            Combat.setCooldown(b, "parry", 20)
            assert(soleCounter(c, k, b) == nil, "a guard still recovering answers nothing")
            Combat.tickCooldowns(c, 20)
            assert(soleCounter(c, k, b), "recovered, it answers again")
        end,
    },
    {
        name = "the reach rules hold: a melee reflex is promised only from an adjacent tile",
        fn = function()
            local knight = fighter("knight", {}, { "iron_sword" })
            local bandit = fighter("bandit", {}, { "iron_sword" }) -- the sword carries Parry
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
            local knight = fighter("knight", {}, { "iron_sword" })
            local duelist = fighter("bandit", {}, { "riposte_blade" })
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
            local priest = fighter("priest", { "keen_senses" }, { "parasitic_staff" })
            local bandit = fighter("bandit", {}, { "iron_sword" })
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
            local mage = fighter("mage", {}, { "wand" })
            local bandit = fighter("bandit", {}, { "iron_sword" }) -- the sword carries Parry
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
        name = "counterPreview walks the same gates the live reflex does",
        fn = function()
            -- mayCounter is the single rule both the hover panel and the onDamaged hooks read, so a
            -- reflex the panel promises is one the hook fires: assert they agree unit by unit.
            local knight = fighter("knight", {}, { "iron_sword" })
            local bandit = fighter("bandit", {}, { "iron_sword" }) -- the sword carries Parry
            local c = Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit(bandit, 2, 1) })
            local k, b = c.units[1], c.units[2]
            local parry
            for _, t in ipairs(b.traits) do if t.id == "parry" then parry = t end end
            assert(parry, "fixture carries the reflex under test")

            assert(Trait.mayCounter(c, b, parry, k, { "physical" }), "adjacent: the gate opens")
            b.x = 5
            assert(not Trait.mayCounter(c, b, parry, k, { "physical" }), "across the field: it shuts")
            b.x = 2
            b.side = k.side
            assert(not Trait.mayCounter(c, b, parry, k, { "physical" }), "a friendly source is never answered")
        end,
    },
}
