-- Tests for the weapon archetype contract (docs/weapons.md). Two halves:
--
--   1. A SWEEP over every weapon blueprint, asserting each one keeps the mechanics its family owes.
--      This is what makes the doc enforced rather than aspirational: a new axe that forgets to cleave,
--      or a weapon that names no family at all, fails the build rather than quietly drifting.
--   2. Per-family behaviour cases for the mechanics this contract introduced -- Bleed's per-tile
--      damage, the staff's Focus swap, the wand's magical routing, and the sword's Parry / the
--      Riposte Blade's deflect-and-answer.
--
-- Pure logic, headless. Fixture style mirrors tests/combat_spec.lua and tests/knockback_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")
local Hazard = require("models.hazard")

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

-- A character with an EMPTY grid, so a case controls exactly what its units carry. Every item can
-- carry traits and stats to its holder (a knight's relic, and now every sword's Parry), so an empty
-- grid is the only clean baseline -- mirrors tests/trait_spec.lua's plainChar.
local function plainChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

-- Put `id` in `char`'s first grid cell and return the instance.
local function give(char, id)
    local item = Item.instantiate(id)
    char.inventory[1] = item
    return item
end

local function hp(u) return u.char.stats.health.current end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Every weapon blueprint, as { id, def } pairs.
local function eachWeapon()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.type == "weapon" then out[#out + 1] = { id = id, def = def } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

return {
    -- ---------------------------------------------------------------- the contract sweep
    {
        name = "every weapon declares exactly one archetype (the family it inherits its mechanics from)",
        fn = function()
            local weapons = eachWeapon()
            assert(#weapons > 0, "the registry found some weapons at all")
            for _, w in ipairs(weapons) do
                local family = Item.archetype(w.def)
                assert(family, w.id .. " declares no archetype tag -- see docs/weapons.md")

                -- Exactly one: two family tags would make Item.archetype depend on tag ORDER, which is
                -- the whole fragility the membership-based encoding exists to rule out.
                local found = {}
                for _, tag in ipairs(w.def.tags or {}) do
                    if Item.ARCHETYPES[tag] then found[#found + 1] = tag end
                end
                assert(#found == 1,
                    w.id .. " declares " .. #found .. " archetype tags (" .. table.concat(found, ", ")
                        .. ") -- a weapon belongs to exactly one family")
            end
        end,
    },
    {
        name = "every weapon keeps the base mechanics its archetype owes (docs/weapons.md)",
        fn = function()
            -- One assertion per family, run against every weapon that claims it. Each is the mechanic
            -- that DEFINES the family -- the thing a new weapon of that kind must not quietly drop.
            local contract = {
                axe = function(ab, id)
                    assert(ab.aoe and ab.aoe.shape == "front",
                        id .. ": an axe cleaves a front arc")
                end,
                spear = function(ab, id)
                    assert(ab.aoe and ab.aoe.shape == "line",
                        id .. ": a spear skewers a line")
                end,
                greatsword = function(ab, id)
                    -- The family contract reads the FOLDED wind-up (Item.windupRange), so a fixed
                    -- `windup = 2` and a chargeable `{ min = 2, max = 5 }` both answer 2 here: the
                    -- floor is one question however the blueprint chose to spell it.
                    assert(Item.windupRange(ab) >= 1, id .. ": a greatsword winds up")
                end,
                bow = function(ab, id)
                    assert((ab.range or 1) >= 2, id .. ": a bow shoots at range")
                    assert((ab.minRange or 0) >= 2, id .. ": a bow has no point-blank shot")
                end,
                longbow = function(ab, id)
                    assert(Item.windupRange(ab) >= 1, id .. ": a longbow is drawn before it looses")
                    assert((ab.range or 1) >= 5, id .. ": a longbow outreaches a bow by two tiles")
                    assert((ab.minRange or 0) >= 2, id .. ": a longbow has no point-blank shot")
                end,
                wand = function(ab, id)
                    assert((ab.range or 1) >= 2, id .. ": a wand strikes at range")
                end,
                dagger = function(ab, id)
                    assert((ab.speed or 99) <= 2, id .. ": a dagger is quick")
                end,
            }
            -- Families whose contract is a whole-item property rather than an ability one.
            local itemContract = {
                staff = function(def, id)
                    assert(def.waitBehavior and def.waitBehavior.kind == "focus",
                        id .. ": a staff swaps Wait for Focus")
                end,
                sword = function(def, id)
                    -- A counter-reaction: the ordinary Parry, a blade that upgrades it (Riposte), or any
                    -- of the parry VARIANTS a named sword carries. Asked of the trait's blueprint rather
                    -- than of a list of ids -- "does this trait answer a blow?" is the actual contract,
                    -- and a whitelist would have to be edited every time a sword buys a new answer, which
                    -- is a test that fails for the wrong reason. A trait answers if it declares a
                    -- `counter` rule (Trait.mayCounter reads it) or negates outright (`deflectsMelee`).
                    local answers = false
                    for _, t in ipairs(def.traits or {}) do
                        local tdef = Trait.defs[t]
                        if tdef and (tdef.counter or tdef.deflectsMelee) then answers = true end
                    end
                    assert(answers, id .. ": a sword answers a melee blow")
                    assert((def.hands or 1) == 1, id .. ": a sword is one-handed")
                end,
                -- Both bow families: one hand holds the stave, the other draws. Checked as an item
                -- property rather than an ability one, since `hands` is a property of the object.
                bow = function(def, id)
                    assert((def.hands or 1) == 2, id .. ": every bow is two-handed")
                end,
                longbow = function(def, id)
                    assert((def.hands or 1) == 2, id .. ": every bow is two-handed")
                end,
                censer = function(def, id)
                    -- The smoke IS the weapon: a censer that emits nothing is just a bad mace.
                    local inc = def.incense
                    assert(inc, id .. ": a censer emits incense")
                    assert(inc.hazard and Hazard.defs[inc.hazard],
                        id .. ": a censer names ground that exists (incense.hazard)")
                    -- A censer must never ALSO swap Wait -- that is the staff's verb, and the two
                    -- families are separated on exactly that line (docs/weapons.md).
                    assert(not def.waitBehavior, id .. ": a censer emits, it does not swap Wait")
                end,
            }

            for _, w in ipairs(eachWeapon()) do
                local family = Item.archetype(w.def)
                local ab = w.def.activeAbility
                if contract[family] then
                    assert(ab, w.id .. " has no activeAbility to check")
                    contract[family](ab, w.id)
                end
                if itemContract[family] then itemContract[family](w.def, w.id) end
            end
        end,
    },
    {
        -- The roster rule from docs/weapons.md: ten weapons per shoppable family, five on a shelf and
        -- five quest-only, with signatures and generals' relics outside the count. Asserted as a shape
        -- rather than per-family so authoring an eleventh sword fails here rather than in a spreadsheet.
        name = "every shoppable family carries ten weapons: five on a shelf, five quest-only",
        fn = function()
            -- Both halves of the catalog: `weapon`s plus the shields, which live in data/items/armor.
            local roster = {}
            for id, def in pairs(Item.defs) do
                local family = Item.archetype(def)
                -- `natural` is a creature's own body and `unarmed` is the player's single hidden fist;
                -- neither is shoppable and neither owes a roster (docs/weapons.md).
                if family and family ~= "natural" and family ~= "unarmed" then
                    -- Signatures, generals' relics, AND discipline weapons sit OUTSIDE the family ten:
                    -- a discipline weapon is additive, locked stock, not part of a base family's 5-on-a-
                    -- shelf + 5-quest balance (docs/classes.md treats them exactly as it treats relics).
                    local excluded = def.discipline ~= nil
                    for _, tag in ipairs(def.tags or {}) do
                        if tag == "signature" or tag == "relic" then excluded = true end
                    end
                    if not excluded then
                        roster[family] = roster[family] or { shop = {}, quest = {} }
                        local half = def.price and "shop" or "quest"
                        table.insert(roster[family][half], id)
                    end
                end
            end

            local families = 0
            for family, halves in pairs(roster) do
                families = families + 1
                assert(#halves.shop == 5, family .. " has " .. #halves.shop
                    .. " shelf weapons, not 5: " .. table.concat(halves.shop, ", "))
                assert(#halves.quest == 5, family .. " has " .. #halves.quest
                    .. " quest-only weapons, not 5: " .. table.concat(halves.quest, ", "))
                -- A quest weapon keeps its `class` (it is what the strike tallies toward for growth) but
                -- must have no `unlockQuests` either -- a shelf gate with no price is dead data on no shelf.
                for _, id in ipairs(halves.quest) do
                    assert(Item.defs[id].class, id .. " is quest-only with no class to tally growth against")
                    assert(not Item.defs[id].unlockQuests, id .. " has an unlockQuests but no price: it is on no shelf")
                end
            end
            assert(families == 13, "expected 13 shoppable families, found " .. families)
        end,
    },
    {
        -- Gates are per-QUEST now (tools/unlock_rescale), so the ceiling is per-HOUSE: an item may not
        -- ask for more quests than its own sponsor actually runs. Anything past that is stock nobody
        -- can ever reach, and the last two quests of a line are the payoff rather than a gate -- so the
        -- real ceiling is Q-2, the number the rescale spreads up to.
        name = "no item is gated past the quests its house actually sponsors",
        fn = function()
            local Vendor = require("models.vendor")
            local Quest = require("models.quest")
            local vendorOf, counts = {}, {}
            for vid, vdef in pairs(Vendor.defs) do
                if vdef.class then vendorOf[vdef.class] = vid end
            end
            for _, qdef in pairs(Quest.defs) do
                if qdef.sponsor then counts[qdef.sponsor] = (counts[qdef.sponsor] or 0) + 1 end
            end
            for id, def in pairs(Item.defs) do
                local gate = def.unlockQuests or 0
                if gate > 0 then
                    local vendorId = def.class and vendorOf[def.class]
                    local sponsored = vendorId and counts[vendorId] or 0
                    assert(gate <= sponsored - 2,
                        id .. " needs " .. gate .. " quests of a house that runs " .. sponsored)
                end
            end
        end,
    },
    {
        name = "a shield swaps Wait for Defend, and is the only armor that does",
        fn = function()
            -- The shield family lives in data/items/armor, not weapon, so the sweep above misses it.
            for id, def in pairs(Item.defs) do
                local isShield = false
                for _, tag in ipairs(def.tags or {}) do
                    if tag == "shield" then isShield = true end
                end
                if isShield then
                    assert(def.waitBehavior and def.waitBehavior.kind == "defend",
                        id .. ": a shield swaps Wait for Defend")
                end
            end
        end,
    },

    -- ---------------------------------------------------------------- bleed (the dagger's verb)
    {
        name = "bleed costs a tile of blood for every tile WALKED, and nothing for standing still",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(plainChar("character_rowan"), 1, 1) },
                { unit(plainChar("character_bandit"), 8, 8) })
            local knight = c.units[1]
            knight.char.stats.staminaRegen = 0
            Status.apply(c, knight, "status_bleed", { magnitude = 3, duration = 99 })

            -- Standing still costs nothing: a wait is not a step.
            local before = hp(knight)
            openTurn(c, knight)
            Combat.wait(c, knight)
            assert(hp(knight) == before, "a bleeding unit that holds still takes nothing")

            -- Walking three tiles costs three ticks of it.
            openTurn(c, knight)
            local moved = Combat.moveUnit(c, knight, 4, 1) -- 3 tiles along a clear row
            assert(moved, "the walk is legal")
            assert(knight.x == 4, "it walked the full three tiles")
            assert(hp(knight) == before - 9, "three tiles bled three times for 3, got " .. (before - hp(knight)))
        end,
    },
    {
        name = "bleed follows a unit dragged across the ground, but never one that blinks",
        fn = function()
            -- Forced movement: shoved two tiles = two tiles of bleeding. Being dragged is still
            -- crossing the ground, which is the whole rule (Combat.enterTile's `reason`).
            local c = Combat.new(arena(8, 8), { unit(plainChar("character_rowan"), 3, 4) },
                { unit(plainChar("character_bandit"), 4, 4) })
            local knight, bandit = c.units[1], c.units[2]
            Status.apply(c, bandit, "status_bleed", { magnitude = 3, duration = 99 })
            local before = hp(bandit)
            Combat.knockback(c, knight, bandit, 2)
            assert(bandit.x == 6, "shoved the full two tiles")
            assert(hp(bandit) == before - 6, "two shoved tiles bled twice, got " .. (before - hp(bandit)))

            -- A teleport crosses no ground at all, so it costs nothing -- the premium a blink buys.
            local c2 = Combat.new(arena(8, 8), { unit(plainChar("character_rowan"), 1, 1) },
                { unit(plainChar("character_bandit"), 8, 8) })
            local k2 = c2.units[1]
            Status.apply(c2, k2, "status_bleed", { magnitude = 3, duration = 99 })
            local hp2 = hp(k2)
            Combat.teleportUnit(c2, k2, 5, 5)
            assert(k2.x == 5 and k2.y == 5, "it leapt across the board")
            assert(hp(k2) == hp2, "a bleeding unit that blinks bleeds not at all")
        end,
    },
    {
        name = "a dagger opens the wound it is named for",
        fn = function()
            local rogue = plainChar("character_bandit")
            local dagger = give(rogue, "weapon_iron_dagger")
            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local attacker, victim = c.units[1], c.units[2]

            openTurn(c, attacker)
            assert(Combat.useItem(c, attacker, dagger, 3, 4), "the stab lands")
            assert(Status.has(victim, "status_bleed"), "and leaves the target bleeding")
        end,
    },

    -- ---------------------------------------------------------------- staff / wand
    {
        name = "a staff swaps its holder's Wait into Focus, and Focus restores mana",
        fn = function()
            local mage = plainChar("character_mage")
            give(mage, "weapon_staff")
            local c = Combat.new(arena(8, 8), { unit(mage, 1, 1) }, { unit(plainChar("character_bandit"), 8, 8) })
            local u = c.units[1]

            assert(Combat.waitBehavior(u).kind == "focus", "the staff's holder Focuses instead of waiting")

            u.char.stats.mana.current = 0
            openTurn(c, u)
            assert(Combat.focus(c, u), "Focus resolves")
            assert(u.char.stats.mana.current > 0, "and put mana back in the pool")
        end,
    },
    {
        name = "a wand's bolt is routed by magic, not muscle",
        fn = function()
            local caster = plainChar("character_mage")
            local wand = give(caster, "weapon_wand")
            local c = Combat.new(arena(8, 8), { unit(caster, 2, 2) }, { unit(plainChar("character_bandit"), 2, 5) })
            local mage, target = c.units[1], c.units[2]

            -- Raising Damage must not move a wand bolt; raising Magic Damage must.
            local base = Combat.computeDamage(c, mage, target, wand)
            mage.char.stats.damage = mage.char.stats.damage + 50
            assert(Combat.computeDamage(c, mage, target, wand) == base,
                "a wand ignores the wielder's Damage stat")
            mage.char.stats.magicDamage = mage.char.stats.magicDamage + 10
            assert(Combat.computeDamage(c, mage, target, wand) == base + 10,
                "a wand scales off Magic Damage")

            -- And it is Magic Defense that turns it, not armor.
            target.char.stats.magicDefense = target.char.stats.magicDefense + 5
            assert(Combat.computeDamage(c, mage, target, wand) == base + 5,
                "a wand is mitigated by Magic Defense")

            openTurn(c, mage)
            assert(Combat.useItem(c, mage, wand, 2, 5), "and it reaches three tiles away")
        end,
    },

    -- ---------------------------------------------------------------- sword: parry / riposte
    {
        name = "a sword answers every melee blow it can afford, at a doubling price",
        fn = function()
            local defender = plainChar("character_bandit")
            give(defender, "weapon_iron_sword")
            local attacker = plainChar("character_bandit")
            give(attacker, "weapon_iron_sword")
            local c = Combat.new(arena(8, 8), { unit(defender, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]
            assert(Trait.has(d, "trait_parry"), "an iron sword carries Parry to its holder")
            -- Stamina is scarce by design, so a swordsman cannot naturally afford two answers (8 + 16)
            -- in one round; prop the pool so this case measures the doubling PRICE, not the bar emptying.
            d.char.stats.stamina.max = 999
            d.char.stats.stamina.current = 999

            local before = hp(a)
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(hp(a) < before, "the defender answered the blow")

            -- Nothing is on cooldown, so a second blow in the same round is answered too. What bounds
            -- it is the price, not a timer.
            local mid = hp(a)
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(hp(a) < mid, "and answers the next one as well -- no guard to recover")
        end,
    },
    {
        name = "a parry costs what the sword costs to swing, and an exhausted swordsman eats the blow",
        fn = function()
            local defender = plainChar("character_bandit")
            give(defender, "weapon_iron_sword")
            local attacker = plainChar("character_bandit")
            give(attacker, "weapon_iron_sword")
            local c = Combat.new(arena(8, 8), { unit(defender, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]
            -- An answer IS a swing, so it is billed the swing's own price -- no second number to tune.
            local swing = Combat.defaultWeapon(d.char).activeAbility.cost.amount

            local stamina = Combat.resource(d.char, "stamina")
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(Combat.resource(d.char, "stamina") == stamina - swing,
                "a parry costs exactly what swinging the sword costs")

            -- Empty the pool: stamina is now the only thing that can stop a parry.
            d.char.stats.stamina.current = swing - 1
            d.answersThisRound = 0
            local before = hp(a)
            Combat.dealFlatDamage(c, d, 5, { "physical" }, "test", a)
            assert(hp(a) == before, "no stamina, no parry")
            assert(d.char.stats.stamina.current == swing - 1,
                "and the answer that never came bills nothing")
        end,
    },
    {
        name = "a riposte too is paid for -- an exhausted duelist's guard drops entirely",
        fn = function()
            local duelist = plainChar("character_bandit")
            give(duelist, "weapon_riposte_blade")
            local attacker = plainChar("character_bandit")
            give(attacker, "weapon_iron_sword")
            local c = Combat.new(arena(8, 8), { unit(duelist, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]
            local swing = Combat.defaultWeapon(d.char).activeAbility.cost.amount

            local stamina = Combat.resource(d.char, "stamina")
            local before = hp(d)
            Combat.dealFlatDamage(c, d, 8, { "physical" }, "test", a)
            assert(hp(d) == before, "the blow is turned aside entirely")
            assert(Combat.resource(d.char, "stamina") == stamina - swing,
                "and a riposte, like a parry, costs a swing")

            -- Spent: the blade no longer negates anything, which is the whole point of pricing it --
            -- a duelist in a doorway can be worn down rather than waited out.
            d.char.stats.stamina.current = swing - 1
            d.answersThisRound = 0
            Combat.dealFlatDamage(c, d, 8, { "physical" }, "test", a)
            assert(hp(d) < before, "an exhausted guard stops nothing")
            assert(d.char.stats.stamina.current == swing - 1,
                "and bills nothing for the guard it never raised")
        end,
    },
    {
        name = "a parry answers an attack, not another parry -- two swordsmen never volley",
        fn = function()
            -- Both carry swords. The attacker's strike provokes ONE counter; that counter must not
            -- provoke a counter-counter, or every exchange in the game becomes a three-hit trade.
            local defender = plainChar("character_bandit")
            give(defender, "weapon_iron_sword")
            local attacker = plainChar("character_bandit")
            local sword = give(attacker, "weapon_iron_sword")
            local c = Combat.new(arena(8, 8), { unit(defender, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]

            local oneSwing = Combat.computeDamage(c, a, d, sword) -- what a single sword blow is worth
            local dBefore, aBefore = hp(d), hp(a)
            openTurn(c, a)
            assert(Combat.useItem(c, a, sword, 3, 3), "the attack lands")

            assert(hp(d) < dBefore, "the defender took the hit")
            assert(hp(a) < aBefore, "and answered it once")
            -- The counter arrived as a reaction, so the attacker's own Parry declined to answer back:
            -- the defender is hit exactly once, by the original swing, and never by a counter-counter.
            local dLost = dBefore - hp(d)
            assert(dLost == oneSwing,
                "the defender is hit once (the swing), not twice: expected " .. oneSwing .. ", got " .. dLost)
        end,
    },
    {
        name = "the Riposte Blade turns a melee blow aside entirely and answers it",
        fn = function()
            local duelist = plainChar("character_bandit")
            give(duelist, "weapon_riposte_blade")
            local attacker = plainChar("character_bandit")
            local sword = give(attacker, "weapon_iron_sword")
            local c = Combat.new(arena(8, 8), { unit(duelist, 3, 3) }, { unit(attacker, 3, 4) })
            local d, a = c.units[1], c.units[2]
            assert(Trait.has(d, "trait_riposte"), "the blade carries Riposte, not the ordinary Parry")

            local dBefore, aBefore = hp(d), hp(a)
            openTurn(c, a)
            assert(Combat.useItem(c, a, sword, 3, 3), "the attack resolves")

            assert(hp(d) == dBefore, "the blow was turned aside: the duelist took NOTHING")
            assert(hp(a) < aBefore, "and the attacker was run through for trying")
        end,
    },
    -- ---------------------------------------------------------------- named weapons earn their price
    -- Each rank-4 weapon must do something its plain iron counterpart does not -- not merely hit for a
    -- bigger number. These lock in that extra.
    {
        name = "the Crescent Blade cuts three tiles down the line, and cuts with magic rather than edge",
        fn = function()
            local hero = plainChar("character_rowan")
            local blade = give(hero, "weapon_crescent_blade")
            local c = Combat.new(arena(8, 8), { unit(hero, 3, 1) },
                { unit(plainChar("character_bandit"), 3, 2),
                  unit(plainChar("character_bandit"), 3, 3),
                  unit(plainChar("character_bandit"), 3, 4),
                  unit(plainChar("character_bandit"), 3, 5) })
            local k = c.units[1]
            local near, mid, far, beyond = c.units[2], c.units[3], c.units[4], c.units[5]

            -- Routed by magic rather than muscle, and turned by Magic Defense rather than armor --
            -- the thing that makes it worth carrying past an iron sword. Read cumulatively, as the
            -- wand's case above is: each line moves one stat off the line before it. Headroom is
            -- bought first (+10 Magic Damage) so the mitigation below can't floor out.
            local base = Combat.computeDamage(c, k, near, blade)
            k.char.stats.damage = k.char.stats.damage + 50
            assert(Combat.computeDamage(c, k, near, blade) == base,
                "the crescent ignores the wielder's Damage stat")
            k.char.stats.magicDamage = k.char.stats.magicDamage + 10
            assert(Combat.computeDamage(c, k, near, blade) == base + 10,
                "and scales off Magic Damage")
            near.char.stats.defense = near.char.stats.defense + 5
            assert(Combat.computeDamage(c, k, near, blade) == base + 10,
                "armor does nothing about it")
            near.char.stats.magicDefense = near.char.stats.magicDefense + 5
            assert(Combat.computeDamage(c, k, near, blade) == base + 5,
                "Magic Defense is what turns it")
            k.char.stats.damage = k.char.stats.damage - 50
            k.char.stats.magicDamage = k.char.stats.magicDamage - 10
            near.char.stats.defense = near.char.stats.defense - 5
            near.char.stats.magicDefense = near.char.stats.magicDefense - 5

            local before = { hp(near), hp(mid), hp(far), hp(beyond) }
            openTurn(c, k)
            assert(Combat.useItem(c, k, blade, 3, 2), "the arc is loosed down the column")
            assert(hp(near) < before[1], "the first tile of the line is cut")
            assert(hp(mid) < before[2], "the second too -- past what a sword could reach")
            assert(hp(far) < before[3], "and the third, which is the whole of what it buys")
            assert(hp(beyond) == before[4], "the fourth stands outside the arc: the line is 3, not endless")
        end,
    },
    {
        name = "the Crescent Blade is paid for out of BOTH pools, and either one empty refuses the swing",
        fn = function()
            local hero = plainChar("character_rowan")
            local blade = give(hero, "weapon_crescent_blade")
            local c = Combat.new(arena(8, 8), { unit(hero, 3, 1) }, { unit(plainChar("character_bandit"), 3, 2) })
            local k = c.units[1]
            local ab = blade.activeAbility

            local costs = Combat.abilityCosts(k, ab)
            assert(#costs == 2, "the blade names two pools, not one")
            local byStat = {}
            for _, cost in ipairs(costs) do byStat[cost.stat] = cost.amount end
            assert(byStat.mana and byStat.stamina, "mana for the crescent, stamina for the arm")

            -- Both pools full: the swing is affordable, and it draws down BOTH.
            k.char.stats.mana.current = byStat.mana
            k.char.stats.stamina.current = byStat.stamina
            assert(Combat.canAfford(k, ab), "with both pools covered, the swing is on")
            openTurn(c, k)
            assert(Combat.useItem(c, k, blade, 3, 2), "and it resolves")
            assert(k.char.stats.mana.current == 0, "the mana half was spent")
            assert(k.char.stats.stamina.current == 0, "and the stamina half with it -- not one or the other")

            -- Either pool short refuses it. The second is the case a single-cost engine would have
            -- missed entirely: plenty of mana, no arm to throw the arc with.
            k.char.stats.mana.current = 0
            k.char.stats.stamina.current = byStat.stamina
            assert(not Combat.canAfford(k, ab), "no mana, no crescent")
            k.char.stats.mana.current = byStat.mana
            k.char.stats.stamina.current = byStat.stamina - 1
            assert(not Combat.canAfford(k, ab), "and no stamina, no swing to carry it")
        end,
    },
    {
        name = "frenzy: each body past the first in the arc raises what EVERY one of them takes",
        fn = function()
            -- The keyword's reference user. One body is a plain cleave; three is the same swing landing
            -- harder on all three -- the inversion that makes being surrounded the point.
            local hero = plainChar("character_rowan")
            give(hero, "weapon_butchers_wedge")
            local c1 = Combat.new(arena(8, 8), { unit(hero, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local a1, lone = c1.units[1], c1.units[2]
            local before1 = hp(lone)
            openTurn(c1, a1)
            assert(Combat.useItem(c1, a1, a1.char.inventory[1], 3, 4), "the lone swing lands")
            local solo = before1 - hp(lone)

            local hero2 = plainChar("character_rowan")
            give(hero2, "weapon_butchers_wedge")
            local c2 = Combat.new(arena(8, 8), { unit(hero2, 3, 3) },
                { unit(plainChar("character_bandit"), 3, 4), unit(plainChar("character_bandit"), 2, 4),
                  unit(plainChar("character_bandit"), 4, 4) })
            local a2, mid = c2.units[1], c2.units[2]
            local before2 = hp(mid)
            openTurn(c2, a2)
            assert(Combat.useItem(c2, a2, a2.char.inventory[1], 3, 4), "the crowded swing lands")
            local crowded = before2 - hp(mid)

            assert(crowded > solo,
                "a swing through three bites deeper than a swing through one: " .. crowded .. " vs " .. solo)
        end,
    },
    {
        name = "frenzy is promised by the damage preview, not just delivered by the swing",
        fn = function()
            -- The tooltip must read the crowd before the player commits, or the number it quotes is a
            -- lie. Both the preview and the live cast run through Combat.castAmount for this reason.
            local hero = plainChar("character_rowan")
            local wedge = give(hero, "weapon_butchers_wedge")
            local c = Combat.new(arena(8, 8), { unit(hero, 3, 3) },
                { unit(plainChar("character_bandit"), 3, 4), unit(plainChar("character_bandit"), 2, 4),
                  unit(plainChar("character_bandit"), 4, 4) })
            local a, mid = c.units[1], c.units[2]

            local preview = Combat.previewAbility(c, a, wedge, 3, 4)
            local entry = preview and preview.entries[mid]
            local promised = entry and entry.damage
            assert(promised and promised > 0, "the preview quotes a number for the middle target")

            local before = hp(mid)
            openTurn(c, a)
            assert(Combat.useItem(c, a, wedge, 3, 4), "the swing lands")
            assert(before - hp(mid) == promised,
                "the swing delivers exactly what the preview promised: " .. (before - hp(mid))
                    .. " vs " .. promised)
        end,
    },
    {
        name = "lifesteal: the Crimson Greataxe drinks a share of everything its arc opens",
        fn = function()
            local hero = plainChar("character_rowan")
            local axe = give(hero, "weapon_crimson_greataxe")
            local c = Combat.new(arena(8, 8), { unit(hero, 3, 3) },
                { unit(plainChar("character_bandit"), 3, 4), unit(plainChar("character_bandit"), 2, 4) })
            local a = c.units[1]
            a.char.stats.health.current = 40 -- leave room for the drink to show
            a.char.stats.stamina.current = 99 -- a heavy greataxe (16) outruns a scarce starting pool

            openTurn(c, a)
            local ok, res = Combat.useItem(c, a, axe, 3, 4)
            assert(ok, "the swing lands")
            assert(res.healed > 0, "and the wielder drank from it")
            assert(hp(a) == 40 + res.healed, "the heal reached the wielder's own bar")

            -- It is the whole arc it drinks from, not just the aimed body: two foes feed it more.
            local solo = plainChar("character_rowan")
            local axe2 = give(solo, "weapon_crimson_greataxe")
            local c2 = Combat.new(arena(8, 8), { unit(solo, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local s = c2.units[1]
            s.char.stats.health.current = 40
            s.char.stats.stamina.current = 99 -- as above: the greataxe outruns a scarce starting pool
            openTurn(c2, s)
            local _, res2 = Combat.useItem(c2, s, axe2, 3, 4)
            assert(res.healed > res2.healed,
                "a swing through two drinks more than a swing through one: "
                    .. res.healed .. " vs " .. res2.healed)
        end,
    },
    {
        name = "a declared lifesteal ADDS to a Vampiric Strike charm beside it, rather than overriding",
        fn = function()
            -- The keyword folds into the same mods.lifesteal the aura feeds, so a hungry weapon charmed
            -- hungrier drinks deeper. Slot 2 is adjacent to slot 1 in the 3x3 grid.
            local plain = plainChar("character_rowan")
            local axe = give(plain, "weapon_crimson_greataxe")
            local c1 = Combat.new(arena(8, 8), { unit(plain, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local u1 = c1.units[1]
            u1.char.stats.health.current = 30
            u1.char.stats.stamina.current = 99 -- the greataxe (16) outruns a scarce starting pool
            openTurn(c1, u1)
            local _, bare = Combat.useItem(c1, u1, axe, 3, 4)

            local charmed = plainChar("character_rowan")
            local axe2 = give(charmed, "weapon_crimson_greataxe")
            charmed.inventory[2] = Item.instantiate("utility_vampiric_strike")
            local c2 = Combat.new(arena(8, 8), { unit(charmed, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local u2 = c2.units[1]
            u2.char.stats.health.current = 30
            u2.char.stats.stamina.current = 99 -- the greataxe (16) outruns a scarce starting pool
            openTurn(c2, u2)
            local _, both = Combat.useItem(c2, u2, axe2, 3, 4)

            assert(both.healed > bare.healed,
                "charmed drinks deeper than bare: " .. both.healed .. " vs " .. bare.healed)
        end,
    },
    {
        -- Saber's rule, and the counterplay to Ira stated as arithmetic (docs/story.md, "The
        -- Colosseum"): Ira scales as her OWN health falls, this scales with its TARGET's. The two are
        -- opposed on one axis, so a long trade wakes her up and wastes Saber entirely.
        --
        -- Deliberately not an accumulate-by-idling design: dead turns are downtime, not patience.
        -- The reward is for reading the board and picking a fresh target, never for abstaining.
        name = "the First Motion pays for opening a fight, not for finishing one",
        fn = function()
            local function swing(targetHpFraction)
                local saber = plainChar("character_saber")
                local blade = give(saber, "weapon_first_motion")
                local mark = plainChar("character_champion")
                local c = Combat.new(arena(8, 8), { unit(saber, 3, 3) }, { unit(mark, 3, 4) })
                local her, foe = c.units[1], c.units[2]

                local php = foe.char.stats.health
                php.current = math.max(1, math.floor(php.max * targetHpFraction))
                local before = hp(foe)

                openTurn(c, her)
                assert(Combat.useItem(c, her, blade, 3, 4), "the wind-up starts")
                -- A greatsword channels a turn before it lands (docs/weapons.md); drive it home.
                Combat.resolveChannel(c, her)
                return before - hp(foe)
            end

            local whole = swing(1.0)
            local wounded = swing(0.25)
            assert(whole > wounded,
                "a target at full health should be worth strictly more, got " .. whole .. " vs " .. wounded)
            assert(wounded > 0, "and a swing into a wounded target is still an ordinary heavy hit")
        end,
    },
    {
        name = "the Kingsblood Dagger puts half a swing again through a wound already open",
        fn = function()
            local rogue = plainChar("character_bandit")
            local blade = give(rogue, "weapon_kingsblood_dagger")
            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local thief, mark = c.units[1], c.units[2]

            -- A clean target: an ordinary strike, and it leaves its own deeper wound behind.
            local before = hp(mark)
            openTurn(c, thief)
            assert(Combat.useItem(c, thief, blade, 3, 4), "the first stab lands")
            local clean = before - hp(mark)
            local wound = Status.get(mark, "status_bleed")
            assert(wound and wound.magnitude == 5, "the Kingsblood cuts deeper than the ordinary 3")

            -- The same blade into the wound it just opened: half the swing again.
            local mid = hp(mark)
            openTurn(c, thief)
            assert(Combat.useItem(c, thief, blade, 3, 4), "the second stab lands")
            local reopened = mid - hp(mark)
            assert(reopened > clean,
                "a bleeding foe takes more than a clean one: " .. reopened .. " vs " .. clean)
        end,
    },
    {
        name = "the Hornbow of the Hunt hits harder the further the shot is taken",
        fn = function()
            -- Same bow, same target, two ranges. The far shot must land harder than the near one --
            -- the inversion that makes this bow want the whole field between it and the kill.
            local near = plainChar("character_archer")
            local nearBow = give(near, "weapon_hornbow_of_the_hunt")
            local c1 = Combat.new(arena(8, 8), { unit(near, 1, 1) }, { unit(plainChar("character_bandit"), 4, 1) })
            local n, nt = c1.units[1], c1.units[2]
            local nBefore = hp(nt)
            openTurn(c1, n)
            assert(Combat.useItem(c1, n, nearBow, 4, 1), "the nearest legal shot lands (3 tiles, minRange)")
            local close = nBefore - hp(nt)

            local far = plainChar("character_archer")
            local farBow = give(far, "weapon_hornbow_of_the_hunt")
            local c2 = Combat.new(arena(8, 8), { unit(far, 1, 1) }, { unit(plainChar("character_bandit"), 6, 1) })
            local f, ft = c2.units[1], c2.units[2]
            local fBefore = hp(ft)
            openTurn(c2, f)
            assert(Combat.useItem(c2, f, farBow, 6, 1), "the long shot lands (5 tiles)")
            local distant = fBefore - hp(ft)

            assert(distant > close,
                "the far shot lands harder: " .. distant .. " vs " .. close)
        end,
    },
    {
        name = "an Oathkeeper Shield braces the whole line, not just the one holding it",
        fn = function()
            local warden = plainChar("character_rowan")
            give(warden, "armor_oathkeeper_shield")
            local c = Combat.new(arena(8, 8),
                { unit(warden, 3, 3), unit(plainChar("character_rowan"), 3, 4), unit(plainChar("character_rowan"), 7, 7) },
                { unit(plainChar("character_bandit"), 8, 8) })
            local holder, beside, away = c.units[1], c.units[2], c.units[3]

            assert(Combat.waitBehavior(holder).kind == "defend", "the shield swaps Wait for Defend")
            openTurn(c, holder)
            assert(Combat.defend(c, holder), "the wall is planted")

            assert(Status.has(holder, "status_defending"), "the holder braces")
            local covered = Status.get(beside, "status_defending")
            assert(covered, "and the ally beside it is covered by the wall")
            assert(covered.magnitude < Status.get(holder, "status_defending").magnitude,
                "the ally gets a lesser share than the one actually holding the shield")
            assert(not Status.has(away, "status_defending"), "an ally across the board is not covered")
        end,
    },
    {
        name = "a plain buckler braces only its holder",
        fn = function()
            -- The counterpart to the case above: `covers` is the Oathkeeper's extra, and the base
            -- shield must NOT have quietly gained it.
            local warden = plainChar("character_rowan")
            give(warden, "armor_buckler")
            local c = Combat.new(arena(8, 8),
                { unit(warden, 3, 3), unit(plainChar("character_rowan"), 3, 4) },
                { unit(plainChar("character_bandit"), 8, 8) })
            local holder, beside = c.units[1], c.units[2]

            openTurn(c, holder)
            assert(Combat.defend(c, holder), "the buckler braces")
            assert(Status.has(holder, "status_defending"), "its holder is braced")
            assert(not Status.has(beside, "status_defending"), "but a buckler covers nobody else")
        end,
    },
    {
        name = "the Quarry's Answer shoots back at range -- and cannot answer a foe in its face",
        fn = function()
            -- The reach rule read from the far side (docs/weapons.md): the counter is bound to the
            -- GRANTING weapon's band, so a bow's dead zone is a dead zone for its reply too.
            local archer = plainChar("character_archer")
            give(archer, "weapon_quarrys_answer")
            local c = Combat.new(arena(8, 8), { unit(archer, 3, 3) },
                { unit(plainChar("character_bandit"), 3, 6), unit(plainChar("character_bandit"), 3, 4) })
            local a, far, near = c.units[1], c.units[2], c.units[3]
            a.char.stats.stamina.max, a.char.stats.stamina.current = 999, 999

            local before = hp(far)
            Combat.dealFlatDamage(c, a, 4, { "physical" }, "test", far)
            assert(hp(far) < before, "a shot from three tiles out is answered with an arrow")

            -- ...and the same bow is silent against the man standing next to it, which is the whole
            -- counter to carrying one.
            a.answersThisRound = 0
            local nearBefore = hp(near)
            Combat.dealFlatDamage(c, a, 4, { "physical" }, "test", near)
            assert(hp(near) == nearBefore, "point-blank is inside the dead zone: no reply")
        end,
    },
    {
        name = "the Stillhunter swaps Wait into Overwatch and shoots what walks into its band",
        fn = function()
            local archer = plainChar("character_archer")
            give(archer, "weapon_stillhunter")
            local c = Combat.new(arena(8, 8), { unit(archer, 1, 1) }, { unit(plainChar("character_bandit"), 5, 1) })
            local watcher, mover = c.units[1], c.units[2]

            assert(Combat.waitBehavior(watcher).kind == "overwatch",
                "the bow's holder watches instead of waiting")
            openTurn(c, watcher)
            assert(Combat.overwatch(c, watcher), "the stance is set")

            local before = hp(mover)
            openTurn(c, mover)
            assert(Combat.moveUnit(c, mover, 3, 1), "the bandit walks into the band (2 tiles off)")
            assert(hp(mover) < before, "and is shot for crossing it")
        end,
    },
    {
        name = "the Hailfall Longbow drops five arrows on five distinct tiles, aim not included",
        fn = function()
            -- Pack every tile of the radius-2 diamond with a body: five of the thirteen are struck,
            -- each exactly once, and WHICH five is the sky's business.
            local archer = plainChar("character_archer")
            local bow = give(archer, "weapon_hailfall_longbow")
            local party = { unit(archer, 5, 1) }
            local foes = {}
            for dx = -2, 2 do
                for dy = -2, 2 do
                    if math.abs(dx) + math.abs(dy) <= 2 then
                        foes[#foes + 1] = unit(plainChar("character_bandit"), 5 + dx, 5 + dy)
                    end
                end
            end
            assert(#foes == 13, "the diamond is thirteen tiles")
            local c = Combat.new(arena(10, 10), party, foes)
            local shooter = c.units[1]
            shooter.char.stats.stamina.max, shooter.char.stats.stamina.current = 999, 999

            local before = {}
            for i = 2, #c.units do before[i] = hp(c.units[i]) end
            openTurn(c, shooter)
            assert(Combat.useItem(c, shooter, bow, 5, 5), "the draw begins")
            Combat.resolveChannel(c, shooter) -- a longbow looses on the turn AFTER the draw

            local struck = 0
            for i = 2, #c.units do
                if hp(c.units[i]) < before[i] then struck = struck + 1 end
            end
            assert(struck == 5, "five arrows, five distinct tiles, five bodies -- got " .. struck)
        end,
    },
    {
        name = "the Deadfall Bow arms a trap on bare ground, and Roots outright when a body is on the tile",
        fn = function()
            -- Both halves of the same purchase (data/items/weapon/weapon_deadfall_bow.lua). The weapon
            -- aims a TILE, which is the point: the shot is placed on the approach, not on the animal.
            local Trap = require("models.trap")
            local archer = plainChar("character_archer")
            local bow = give(archer, "weapon_deadfall_bow")
            local c = Combat.new(arena(10, 10),
                { unit(archer, 2, 2) }, { unit(plainChar("character_bandit"), 6, 2) })
            local shooter, bandit = c.units[1], c.units[2]
            shooter.char.stats.stamina.max, shooter.char.stats.stamina.current = 999, 999

            -- EMPTY GROUND: the shaft is planted and left armed. Aimed at (5,2), a tile nobody stands on.
            openTurn(c, shooter)
            assert(Combat.useItem(c, shooter, bow, 5, 2), "the draw begins on a tile with nobody on it")
            Combat.resolveChannel(c, shooter) -- a longbow looses on the turn AFTER the draw
            local trap = Trap.at(c, 5, 2)
            assert(trap and trap.id == "bear_trap", "a bear trap is armed on the aimed cell")
            assert(trap.side == "party", "and it belongs to the hunter's side")
            -- The trap carries the ARCHER'S OWN DRAW, not an authored constant. A trap's payload runs
            -- through Combat.dealFlatDamage, which adds no attack stat -- so a flat figure is the whole
            -- blow forever while the arrow beside it grows every level. Authored flat at 6, this landed
            -- ONE point on the boar of the very quest that grants the bow. Asserted as a comparison
            -- against the wielder's stat rather than a literal, so the ladder may move the bow's power
            -- without this needing an edit.
            local drew = shooter.char.stats.damage or 0
            assert(drew > 0, "the archer swings for something, or this comparison proves nothing")
            assert((trap.amount or 0) > drew,
                string.format("the trap is armed with the shot's weight plus the draw (%d), not a flat"
                    .. " constant -- got %s", drew, tostring(trap.amount)))
            assert(hp(bandit) == bandit.char.stats.health.max, "the foe two tiles off is untouched")

            -- OCCUPIED: the same aim, now with the foe standing on it. The hold is delivered at once
            -- and nothing is left behind -- a trap under a body already caught is the sale billed twice.
            local before = hp(bandit)
            openTurn(c, shooter)
            assert(Combat.useItem(c, shooter, bow, 6, 2), "the aim is legal on an occupied tile too")
            Combat.resolveChannel(c, shooter)
            assert(hp(bandit) < before, "the shaft goes through the body")
            assert(Status.has(bandit, "status_root"), "and holds it where it stands")
            assert(Trap.at(c, 6, 2) == nil, "no trap is left under the one it already caught")
        end,
    },
    {
        name = "the Shepherd's Crook drives a foe two tiles and advances with it",
        fn = function()
            -- The one mace that moves its own wielder. Every other one in the family shoves a body away
            -- and stays exactly where it stood, so what is checked is that BOTH bodies travelled the two
            -- tiles and that the knight is still at the point of the hook -- Combat.charge moves the pair
            -- in LOCKSTEP for the whole drive, so the knight ends up directly behind the foe's landing
            -- tile rather than stopping on the square it first vacated.
            local knight = plainChar("character_knight")
            local crook = give(knight, "weapon_shepherds_crook")
            local c = Combat.new(arena(10, 10),
                { unit(knight, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local k, foe = c.units[1], c.units[2]
            k.char.stats.stamina.max, k.char.stats.stamina.current = 999, 999
            foe.char.stats.health.max, foe.char.stats.health.current = 400, 400 -- it has to survive the hook

            local before = hp(foe)
            openTurn(c, k)
            assert(Combat.useItem(c, k, crook, 3, 4), "the hook catches")
            assert(hp(foe) < before, "it is a mace, so the blow lands too")
            -- Driven straight along the lane away from the knight: (3,4) -> (3,6).
            assert(foe.x == 3 and foe.y == 6,
                string.format("the foe is driven two tiles, not to (%d, %d)", foe.x, foe.y))
            assert(k.x == 3 and k.y == 5,
                string.format("and the knight comes with it, still at the point of the hook,"
                    .. " not to (%d, %d)", k.x, k.y))
        end,
    },
    {
        name = "the Arcanum's three quest wands each strike a foe and pay their own caster",
        fn = function()
            -- One case for the trio, because the SHAPE is the thing: all three are a bolt at an enemy that
            -- leaves its own caster holding the status the wand is named for. Written as a table so a
            -- fourth of them cannot be added without either fitting the shape or being noticed.
            local wands = {
                { id = "weapon_sealed_ward_wand", status = "status_sealed_ward" },
                { id = "weapon_reflecting_wand", status = "status_reflect_magic" },
                { id = "weapon_second_utterance_wand", status = "status_second_utterance" },
            }
            for _, w in ipairs(wands) do
                local mage = plainChar("character_mage")
                local wand = give(mage, w.id)
                local c = Combat.new(arena(8, 8),
                    { unit(mage, 3, 3) }, { unit(plainChar("character_bandit"), 3, 5) })
                local m, foe = c.units[1], c.units[2]
                m.char.stats.mana.max, m.char.stats.mana.current = 999, 999
                foe.char.stats.health.max, foe.char.stats.health.current = 400, 400

                local before = hp(foe)
                openTurn(c, m)
                assert(Combat.useItem(c, m, wand, 3, 5),
                    w.id .. " is thrown at a foe, not handed to a friend")
                assert(hp(foe) < before, w.id .. " is a bolt: the blow lands")
                assert(Status.has(m, w.status),
                    w.id .. " leaves its CASTER holding " .. w.status)
                assert(not Status.has(foe, w.status),
                    w.id .. " does not put it on the target -- the rider is the caster's")
            end
        end,
    },
    {
        name = "Sealed Hand is an ability now, and it cuts a foe off rather than warding a friend",
        fn = function()
            -- The anti-support curse left the wand trio (a curse laid on somebody else does not fit three
            -- wands named for what they leave on their own caster) and became a grid cell. Its two
            -- directions -- refuses help, ignores harm -- are pinned in tests/imported_kit_spec.lua.
            local mage = plainChar("character_mage")
            local curse = give(mage, "ability_sealed_hand")
            local c = Combat.new(arena(8, 8),
                { unit(mage, 3, 3) }, { unit(plainChar("character_bandit"), 3, 5) })
            local m, foe = c.units[1], c.units[2]
            m.char.stats.mana.max, m.char.stats.mana.current = 999, 999

            openTurn(c, m)
            assert(Combat.useItem(c, m, curse, 3, 5), "the seal is laid on the foe")
            assert(Status.has(foe, "status_sealed_hand"), "and it is the FOE that is cut off from help")
            assert(not Status.has(m, "status_sealed_hand"), "never the caster")
        end,
    },
    {
        name = "Second Utterance can be handed to somebody else, which the charm cannot do",
        fn = function()
            -- The ability half of what the old ally-targeted wand used to sell. The charm
            -- (utility_second_utterance) banks the free cast for its own bearer after a channel of theirs
            -- lands; this gives it to a different body, on demand, having asked nothing first.
            local mage = plainChar("character_mage")
            local gift = give(mage, "ability_second_utterance")
            local c = Combat.new(arena(8, 8),
                { unit(mage, 3, 3), unit(plainChar("character_knight"), 3, 4) },
                { unit(plainChar("character_bandit"), 7, 7) })
            local m, ally = c.units[1], c.units[2]
            m.char.stats.mana.max, m.char.stats.mana.current = 999, 999

            openTurn(c, m)
            assert(Combat.useItem(c, m, gift, 3, 4), "the mage speaks for the knight")
            assert(Status.has(ally, "status_second_utterance"),
                "and the knight's next channelled working will resolve at once")
        end,
    },
    {
        name = "a wand's ward is shorter than the ability that grants the same thing standing",
        fn = function()
            -- The reason the wands do not retire ability_reflect_magic. The ability spends a whole slow
            -- turn and can be pointed at anybody; the wand takes the same status as a rider on a bolt and
            -- must therefore hold it for less time -- long enough to cover the reply to the shot, not the
            -- fight. Compared against the status's OWN default rather than a literal, so tuning the
            -- status does not silently invert the relationship this is here to protect.
            local Status_defs = require("models.status").defs
            local mage = plainChar("character_mage")
            local wand = give(mage, "weapon_reflecting_wand")
            local c = Combat.new(arena(8, 8),
                { unit(mage, 3, 3) }, { unit(plainChar("character_bandit"), 3, 5) })
            local m = c.units[1]
            m.char.stats.mana.max, m.char.stats.mana.current = 999, 999
            m.char.stats.health.max, m.char.stats.health.current = 400, 400

            openTurn(c, m)
            assert(Combat.useItem(c, m, wand, 3, 5), "the bolt lands")
            local mirrored
            for _, s in ipairs(m.statuses or {}) do
                if s.id == "status_reflect_magic" then mirrored = s end
            end
            assert(mirrored, "the mage is Mirrored")
            -- `remaining` is where Status.instantiate puts the ticks; `duration` lives on the DEF.
            local standing = Status_defs.status_reflect_magic.duration
            assert((mirrored.remaining or standing) < standing,
                string.format("a rider's ward runs shorter than a cast one (%s against %d)",
                    tostring(mirrored.remaining), standing))
        end,
    },
    {
        name = "the Slipknife answers a shot from across the board by arriving beside the shooter",
        fn = function()
            local rogue = plainChar("character_bandit")
            give(rogue, "weapon_slipknife")
            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 3) }, { unit(plainChar("character_archer"), 3, 7) })
            local r, shooter = c.units[1], c.units[2]
            r.char.stats.stamina.max, r.char.stats.stamina.current = 999, 999

            local before = hp(shooter)
            Combat.dealFlatDamage(c, r, 4, { "physical" }, "test", shooter)
            local dist = math.abs(r.x - shooter.x) + math.abs(r.y - shooter.y)
            assert(dist == 1, "the knife crossed the four tiles and is standing beside the archer")
            assert(hp(shooter) < before, "and cut it on arrival")
        end,
    },
    {
        name = "a Slipknife has nowhere to arrive when its attacker is hemmed in, and answers nothing",
        fn = function()
            -- The counterplay, and it is positional rather than a timer: fill every tile around the
            -- attacker and the reflex simply has no landing.
            local rogue = plainChar("character_bandit")
            give(rogue, "weapon_slipknife")
            local c = Combat.new(arena(8, 8), { unit(rogue, 5, 5) },
                { unit(plainChar("character_archer"), 1, 1), unit(plainChar("character_bandit"), 2, 1),
                  unit(plainChar("character_bandit"), 1, 2), unit(plainChar("character_bandit"), 2, 2) })
            local r, shooter = c.units[1], c.units[2]
            r.char.stats.stamina.max, r.char.stats.stamina.current = 999, 999

            local before, stamina = hp(shooter), Combat.resource(r.char, "stamina")
            Combat.dealFlatDamage(c, r, 4, { "physical" }, "test", shooter)
            assert(r.x == 5 and r.y == 5, "the rogue stayed exactly where it was")
            assert(hp(shooter) == before, "and answered nothing")
            assert(Combat.resource(r.char, "stamina") == stamina,
                "an answer that never came bills nothing")
        end,
    },
    {
        name = "the Mailpiercer ignores armour outright and Halts the second rank",
        fn = function()
            local knight = plainChar("character_rowan")
            local pike = give(knight, "weapon_mailpiercer")
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 3) },
                { unit(plainChar("character_bandit"), 3, 4), unit(plainChar("character_bandit"), 3, 5) })
            local k, front, back = c.units[1], c.units[2], c.units[3]
            k.char.stats.stamina.max, k.char.stats.stamina.current = 999, 999

            local f0, b0 = hp(front), hp(back)
            openTurn(c, k)
            assert(Combat.useItem(c, k, pike, 3, 4), "the thrust runs down the column")
            local plain = f0 - hp(front)
            assert(plain > 0 and hp(back) < b0, "both ranks are skewered")
            assert(Status.has(back, "status_halted"), "and the far one is pinned off its turn")
            assert(not Status.has(front, "status_halted"), "the near one is only wounded")

            -- Armour has nothing to say about it: twenty points of defense change the number by zero.
            front.char.stats.health.current = front.char.stats.health.max
            front.char.stats.defense = front.char.stats.defense + 20
            local f1 = hp(front)
            openTurn(c, k)
            assert(Combat.useItem(c, k, pike, 3, 4), "the second thrust lands")
            assert(f1 - hp(front) == plain,
                "raw: armoured and unarmoured take the same, got " .. (f1 - hp(front)) .. " vs " .. plain)
        end,
    },
    {
        name = "the Marching Standard plants its colours as it thrusts, and never disarms its bearer",
        fn = function()
            local knight = plainChar("character_rowan")
            local pike = give(knight, "weapon_marching_standard")
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local k = c.units[1]
            k.char.stats.stamina.max, k.char.stats.stamina.current = 999, 999

            local function banners()
                local n = 0
                for _, u in ipairs(c.units) do
                    if u.alive and u.char.name == "Banner" then n = n + 1 end
                end
                return n
            end

            openTurn(c, k)
            assert(Combat.useItem(c, k, pike, 3, 4), "the first thrust lands")
            assert(banners() == 1, "and drives the standard into the ground beside the knight")
            assert(Hazard.at(c, k.standard.x, k.standard.y, "hazard_rally"),
                "the square under it is Rally ground")
            -- The whole reason it plants without taking the item's summon claim: a weapon that fell
            -- silent while its own standard stood would be disarming its bearer.
            assert(Combat.itemBlockReason(k, pike) == nil, "the pike is still a pike")

            openTurn(c, k)
            assert(Combat.useItem(c, k, pike, 3, 4), "the second thrust lands too")
            assert(banners() == 1, "but raises no second standard while the first stands")

            -- Cut it down and the next thrust raises it again -- the duality, and it is a board state.
            k.standard.alive = false
            openTurn(c, k)
            assert(Combat.useItem(c, k, pike, 3, 4), "the third thrust lands")
            assert(banners() == 1 and k.standard.alive, "the colours are back up")
        end,
    },
    {
        name = "the Wand of the Turning Year alternates its seasons, and its bearer feels neither",
        fn = function()
            local mage = plainChar("character_mage")
            local wand = give(mage, "weapon_turning_year")
            local c = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit(plainChar("character_bandit"), 2, 5) })
            local m, target = c.units[1], c.units[2]
            m.char.stats.mana.max, m.char.stats.mana.current = 999, 999
            -- Room to take both halves of the year. This spec is about the RHYTHM, not about lethality,
            -- and the wand's power is a slot-graded number that moves (Balance.slotTarget) -- when it
            -- rose the bandit started dying to the second bolt and the frost had nobody to land on, so
            -- the test failed on a fact about hit points rather than about the alternation.
            target.char.stats.health.max = 400
            target.char.stats.health.current = 400

            openTurn(c, m)
            assert(Combat.useItem(c, m, wand, 2, 5), "the first bolt lands")
            assert(Status.has(target, "status_burn"), "a battle opens on fire")
            assert(not Status.has(target, "status_freeze"), "and only fire")

            openTurn(c, m)
            assert(Combat.useItem(c, m, wand, 2, 5), "the second bolt lands")
            assert(Status.has(target, "status_freeze"), "the year turns: the next one is frost")

            -- The rhythm must not turn just from LOOKING. The damage preview replays this effect, so a
            -- half banked straight onto the unit would flip every hover frame -- the flicker that sent
            -- the tooltip and timeline volleying between the fire bolt and the frost's delay. fx.bank is
            -- inert in the preview, so a hover reports the branch THIS cast would run and turns nothing.
            local half = m.turningYear
            assert(Combat.previewAbility(c, m, wand, 2, 5), "the wand previews its next bolt")
            assert(m.turningYear == half, "hovering does not turn the year")
            Combat.previewAbility(c, m, wand, 2, 5)
            Combat.previewAbility(c, m, wand, 2, 5)
            assert(m.turningYear == half, "and no number of hovers does either")

            -- The other half of what it sells: the bearer cannot be given either of them, by anybody.
            Status.apply(c, m, "status_burn")
            Status.apply(c, m, "status_freeze")
            assert(not Status.has(m, "status_burn"), "its bearer cannot burn")
            assert(not Status.has(m, "status_freeze"), "nor freeze")
        end,
    },
    -- ---------------------------------------------------------------- the new engine keywords
    -- Four mechanisms this catalog added, each pinned by the one weapon that spends it. They are engine
    -- surface rather than data, so a regression here would silently flatten several weapons at once.
    {
        name = "steadfast: Kingsfall's wind-up survives the stun that would break any other greatsword",
        fn = function()
            -- The control still lands in full; only the cancellation is refused (docs/weapons.md).
            local her = plainChar("character_rowan")
            local blade = give(her, "weapon_kingsfall")
            local c = Combat.new(arena(8, 8), { unit(her, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local k, foe = c.units[1], c.units[2]
            k.char.stats.stamina.max, k.char.stats.stamina.current = 999, 999

            openTurn(c, k)
            assert(Combat.useItem(c, k, blade, 3, 4), "the wind-up starts")
            assert(k.channel, "and it is channelling")
            Status.apply(c, k, "status_stun", { applier = foe })
            assert(Status.has(k, "status_stun"), "the stun landed in full -- it is not refused")
            assert(k.channel, "but the wind-up did not break")

            -- The control-breaks-a-channel rule is still live for everyone else.
            local other = plainChar("character_rowan")
            local plain = give(other, "weapon_iron_greatsword")
            local c2 = Combat.new(arena(8, 8), { unit(other, 3, 3) }, { unit(plainChar("character_bandit"), 3, 4) })
            local o, foe2 = c2.units[1], c2.units[2]
            o.char.stats.stamina.max, o.char.stats.stamina.current = 999, 999
            openTurn(c2, o)
            assert(Combat.useItem(c2, o, plain, 3, 4), "the plain greatsword winds up too")
            Status.apply(c2, o, "status_stun", { applier = foe2 })
            assert(not o.channel, "and an ordinary greatsword's wind-up IS shattered")
        end,
    },
    {
        name = "channelStatus: drawing the Held Breath hides the archer through the wind-up",
        fn = function()
            local archer = plainChar("character_archer")
            local bow = give(archer, "weapon_held_breath")
            local c = Combat.new(arena(10, 10), { unit(archer, 1, 1) }, { unit(plainChar("character_bandit"), 1, 6) })
            local a = c.units[1]
            a.char.stats.stamina.max, a.char.stats.stamina.current = 999, 999

            assert(not Status.has(a, "status_invisible"), "it is visible before it draws")
            openTurn(c, a)
            assert(Combat.useItem(c, a, bow, 1, 6), "the draw begins")
            assert(Status.has(a, "status_invisible"),
                "and the archer is unseen on the very beat it committed -- the turn it had to survive")
        end,
    },
    {
        name = "a wait swap's status / toll / afflicts land on Focus",
        fn = function()
            -- `status`: the Warding Staff raises a ward as it meditates.
            local mage = plainChar("character_mage")
            give(mage, "weapon_warding_staff")
            local c = Combat.new(arena(8, 8), { unit(mage, 1, 1) }, { unit(plainChar("character_bandit"), 8, 8) })
            local m = c.units[1]
            m.char.stats.mana.current = 0
            openTurn(c, m)
            assert(Combat.focus(c, m), "Focus resolves")
            assert(m.char.stats.mana.current > 0, "and put mana back")
            assert(Status.has(m, "status_magical_barrier"), "...and raised the ward with it")

            -- `toll`: the Overchannelled Staff buys its deeper mana with the focuser's own blood.
            local bled = plainChar("character_mage")
            give(bled, "weapon_overchannelled_staff")
            local c2 = Combat.new(arena(8, 8), { unit(bled, 1, 1) }, { unit(plainChar("character_bandit"), 8, 8) })
            local b = c2.units[1]
            b.char.stats.mana.current = 0
            local hpBefore = hp(b)
            openTurn(c2, b)
            assert(Combat.focus(c2, b), "the deep Focus resolves")
            assert(b.char.stats.mana.current > 0, "it returned mana")
            assert(hp(b) < hpBefore, "and took health for it")

            -- `afflicts`: `covers` pointed outward. The Gag-Crook cuts off adjacent ENEMIES only.
            local priest = plainChar("character_priest")
            give(priest, "weapon_gag_crook")
            local c3 = Combat.new(arena(8, 8),
                { unit(priest, 3, 3), unit(plainChar("character_mage"), 3, 2) },
                { unit(plainChar("character_bandit"), 3, 4) })
            local p, friend, foe = c3.units[1], c3.units[2], c3.units[3]
            openTurn(c3, p)
            assert(Combat.focus(c3, p), "the priest sits down")
            assert(Status.has(foe, "status_magic_denied"), "the enemy beside it is cut off from magic")
            assert(not Status.has(friend, "status_magic_denied"),
                "and the ally beside it is not -- `afflicts` is the hostile half, not a zone")
        end,
    },
    {
        name = "coversStatus: the Given Guard lends its wall away and goes without it",
        fn = function()
            local knight = plainChar("character_rowan")
            give(knight, "armor_given_guard")
            local c = Combat.new(arena(8, 8),
                { unit(knight, 3, 3), unit(plainChar("character_mage"), 3, 4), unit(plainChar("character_mage"), 7, 7) },
                { unit(plainChar("character_bandit"), 8, 8) })
            local holder, beside, away = c.units[1], c.units[2], c.units[3]

            assert(Combat.waitBehavior(holder).kind == "defend", "it is a shield")
            openTurn(c, holder)
            assert(Combat.defend(c, holder), "the wall is planted")

            assert(Status.has(beside, "status_lent_guard"), "the ally beside it is wearing the knight's guard")
            assert(Status.has(holder, "status_given_guard"), "and the knight is going without it")
            assert(not Status.has(away, "status_lent_guard"), "an ally across the board gets nothing")
        end,
    },
    {
        name = "a wait swap's hazard is planted and left, not carried like incense",
        fn = function()
            -- The line that separates a staff from a censer (docs/weapons.md): a censer's cloud is lifted
            -- and re-laid on every step, and this is not.
            local mage = plainChar("character_mage")
            give(mage, "weapon_graven_circle_staff")
            local c = Combat.new(arena(8, 8), { unit(mage, 3, 3) }, { unit(plainChar("character_bandit"), 8, 8) })
            local m = c.units[1]

            openTurn(c, m)
            assert(Combat.focus(c, m), "the sigils are cut")
            assert(Hazard.at(c, 3, 3, "hazard_graven_circle"), "the ground under the mage is graven")

            openTurn(c, m)
            assert(Combat.moveUnit(c, m, 6, 3), "the mage walks away from its own circle")
            assert(Hazard.at(c, 3, 3, "hazard_graven_circle"),
                "the circle STAYS where it was cut -- a staff plants, it does not carry")
            assert(not Hazard.at(c, 6, 3, "hazard_graven_circle"),
                "and none of it followed: that lifting-and-relaying is the censer's mechanic, not this one")
        end,
    },
    {
        name = "a riposte turns aside only what a blade can reach and touch",
        fn = function()
            -- Ranged: the guard is worth nothing to an archer three tiles off.
            local duelist = plainChar("character_bandit")
            give(duelist, "weapon_riposte_blade")
            local archer = plainChar("character_archer")
            local bow = give(archer, "weapon_iron_bow")
            local c = Combat.new(arena(8, 8), { unit(duelist, 3, 3) }, { unit(archer, 3, 6) })
            local d, a = c.units[1], c.units[2]

            local before = hp(d)
            openTurn(c, a)
            assert(Combat.useItem(c, a, bow, 3, 3), "the shot resolves")
            assert(hp(d) < before, "an arrow flies straight past a raised guard")

            -- Magical: a spell is not something a blade can turn, even at point-blank.
            local d2 = plainChar("character_bandit")
            give(d2, "weapon_riposte_blade")
            local c2 = Combat.new(arena(8, 8), { unit(d2, 3, 3) }, { unit(plainChar("character_mage"), 3, 4) })
            local du, mg = c2.units[1], c2.units[2]
            local hp2 = hp(du)
            Combat.dealFlatDamage(c2, du, 8, { "magical" }, "test", mg)
            assert(hp(du) < hp2, "a spell passes through the guard")
        end,
    },
}
