-- Tests for THE SABERTOOTHS (Gluttony's approach floor, 2026-09-23): the line, its fights, its drops, and
-- the engine seams it needed --
--   * Combat.startTurn stamps `openedUnseen` (hidden when the turn arrived, or veiled at its top), and
--     spends `veilNext`, the latch The Unbroken Stalk sets on a kill made from hiding
--   * a reach an ability only has from hiding (`hiddenRange`, read by Combat.abilityRange)
--   * Combat.forcesCrit: a critical that is a certainty, not a roll -- the Pounce, the Ambush Charm's
--     `critUnseen` aura and the Stalker's Mantle -- asked by critChance and the blow alike
--   * the Trophy Cord's count lives on the piece, survives a save, and empties at the Gate
-- Each case pins a rule the review approved ("The Sabertooth", round three), on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Player = require("models.player")
local Save = require("models.save")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = { "character_sabertooth", "character_the_longfang" }
local KIT = { "weapon_pounce", "utility_tawny_hide", "utility_wood_walker", "utility_the_longfangs_hunt" }
local DROPS = {
    character_sabertooth = { "armor_stalkers_mantle", "utility_ambush_charm", "utility_trophy_cord" },
    character_the_longfang = { "utility_the_unbroken_stalk" },
}

-- A company body sturdy enough to survive a critical bite unless a case says otherwise.
local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function board(n, opts) return Fixture.new(n or 9, n or 9, opts) end

local function gap(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

-- Open `u`'s turn through the real door, so the veil and the unseen stamp are what the engine decides.
local function standUp(c, u)
    for _, other in ipairs(c.units) do other.initiative = (other == u) and 0 or 50 end
    assert(Combat.startTurn(c) == u, "the chosen body is the one that stands up")
end

-- Open a turn the cat came up to hidden.
local function hiddenTurn(c, cat)
    Status.apply(c, cat, "status_invisible")
    standUp(c, cat)
    assert(Combat.unseenFor(c, cat), "the turn was opened unseen")
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the sabertooth kit is creature stock, and every drop is a person's unstocked trophy",
        fn = function()
            for _, id in ipairs(KIT) do
                local def = Item.defs[id]
                assert(def, "kit item exists: " .. id)
                assert(def.class == "creature" and def.noSteal, id .. " is unstealable creature kit")
                assert(def.price == nil and def.unlockLevel == nil, id .. " carries no price and no rung")
            end
            for _, bodyId in ipairs(BODIES) do
                local body = Character.defs[bodyId]
                assert(body, "body exists: " .. bodyId)
                local depth = -1
                for i, id in ipairs(DROPS[bodyId]) do
                    local def = Item.defs[id]
                    assert(def and def.class ~= "creature", "drop is a person's item: " .. id)
                    assert(def.unstocked and def.price == nil, id .. " is seen on the rack and never sold")
                    assert(def.unlockLevel > depth, id .. " sits deeper than the drop above it")
                    depth = def.unlockLevel
                    assert(body.drops[i] == id, bodyId .. " drop " .. i .. " is " .. id)
                end
            end
            -- The hiding is the Smoke Mantle's own rule, not a second one.
            local traits = Item.defs["utility_tawny_hide"].traits
            assert(traits[1] == "trait_smoke_mantle", "the Tawny Hide wears the Smoke Mantle's trait")
            assert(Item.defs["utility_the_unbroken_stalk"].traits[1]
                == Item.defs["utility_the_longfangs_hunt"].traits[1], "the Longfang's rule and its drop are one trait")
        end,
    },
    {
        name = "two ordinary fights homed on the wood's approach, and only the Pride fields the Longfang",
        fn = function()
            for _, id in ipairs({ "encounter_the_sabertooths", "encounter_the_pride" }) do
                local enc = Encounter.get(id)
                assert(enc.kind == "combat" and enc.rung == 1, id .. " is ordinary traffic on rung 1")
                assert(enc.condition({ biome = "forest" }) and not enc.condition({ biome = "castle" }),
                    id .. " is locked to the wood")
            end
            for seed = 1, 40 do
                local ctx = { depth = 1, rung = 1, biome = "forest", seed = seed }
                local pair = Encounter.get("encounter_the_sabertooths").composition(ctx)
                assert(#pair >= 2 and #pair <= 3, "the Sabertooths field two or three (" .. #pair .. ")")
                for _, id in ipairs(pair) do assert(id == "character_sabertooth", "cats only") end
                local pride = Encounter.get("encounter_the_pride").composition(ctx)
                assert(pride[1] == "character_the_longfang", "the Pride is led by the Longfang")
                assert(#pride >= 2 and #pride <= 3, "and one or two of her cats (" .. #pride .. ")")
            end
        end,
    },

    -- ------------------------------------------------------------------------------ hiding
    {
        name = "a cat that drew no blood opens its next turn Invisible, and a Marked one cannot",
        fn = function()
            local c = Combat.new(board(), { walker(1, 1) }, { unit("character_sabertooth", 8, 8) })
            local cat = c.units[2]
            cat.lastTurnHits = Combat.tallyCount(cat, "hitDealt")
            standUp(c, cat)
            assert(Status.has(cat, "status_invisible"), "an idle turn opens unseen, on open ground")
            assert(Combat.unseenFor(c, cat), "and the turn is stamped as opened unseen")

            Status.remove(c, cat, "status_invisible")
            Status.apply(c, cat, "status_mark")
            cat.lastTurnHits = Combat.tallyCount(cat, "hitDealt")
            standUp(c, cat)
            assert(not Status.has(cat, "status_invisible"), "a Mark forbids the veil")
            assert(not Combat.unseenFor(c, cat), "and so a Marked cat has no pounce")
        end,
    },

    -- ------------------------------------------------------------------------------ the pounce
    {
        name = "Pounce reaches three tiles only on a turn opened unseen",
        fn = function()
            local c = Combat.new(board(), { walker(2, 5) }, { unit("character_sabertooth", 5, 5) })
            local prey, cat = c.units[1], c.units[2]
            local pounce = itemNamed(cat.char, "weapon_pounce")
            standUp(c, cat)
            local seen = {}
            for _, t in ipairs(Combat.abilityTargets(c, cat, pounce)) do seen[t] = true end
            assert(not seen[prey], "seen, the bite only reaches beside it")
            hiddenTurn(c, cat)
            seen = {}
            for _, t in ipairs(Combat.abilityTargets(c, cat, pounce)) do seen[t] = true end
            assert(seen[prey], "opened unseen, it reaches three tiles")
        end,
    },
    {
        name = "a pounce lands beside its target, is a critical, and brings the cat out of hiding",
        fn = function()
            local c = Combat.new(board(), { walker(2, 5), walker(5, 8) }, { unit("character_sabertooth", 5, 5) })
            local prey, near, cat = c.units[1], c.units[2], c.units[3]
            local pounce = itemNamed(cat.char, "weapon_pounce")

            -- A plain bite first, beside the target and seen, for the number a critical triples.
            near.x, near.y = 5, 6
            standUp(c, cat)
            assert(Combat.critChance(c, cat, near, pounce) < 100, "seen, the bite is not a certain critical")
            local before = hp(near)
            assert(Combat.useItem(c, cat, pounce, near.x, near.y), "the plain bite lands")
            local plain = before - hp(near)
            near.x, near.y = 9, 9

            hiddenTurn(c, cat)
            assert(Combat.critChance(c, cat, prey, pounce) == 100, "the forecast says critical")
            before = hp(prey)
            assert(Combat.useItem(c, cat, pounce, prey.x, prey.y), "the pounce is made from three tiles")
            assert(gap(cat, prey) == 1, "the cat lands beside its target (gap " .. gap(cat, prey) .. ")")
            local dealt = before - hp(prey)
            assert(dealt == plain * Combat.CRIT_MULTIPLIER,
                "and the bite is a critical (" .. dealt .. " vs " .. plain .. " x3)")
            assert(not Status.has(cat, "status_invisible"), "the pounce ends Invisible")
        end,
    },
    {
        name = "a counter thrown out of turn keeps its roll: forced criticals are the striker's own turn only",
        fn = function()
            local c = Combat.new(board(), { walker(4, 5) }, { unit("character_sabertooth", 5, 5) })
            local foe, cat = c.units[1], c.units[2]
            Status.apply(c, cat, "status_invisible")
            openTurn(c, foe)
            assert(not Combat.forcesCrit(c, cat, foe, itemNamed(cat.char, "weapon_pounce")),
                "on somebody else's turn the cat's bite is not forced")
        end,
    },

    -- ------------------------------------------------------------------------------ the Longfang
    {
        name = "the Longfang's kill keeps her hidden and opens her next turn hidden; a plain cat's does not",
        fn = function()
            for _, case in ipairs({ { id = "character_the_longfang", kept = true },
                                    { id = "character_sabertooth", kept = false } }) do
                local c = Combat.new(board(), { walker(2, 5, 5), walker(9, 9) }, { unit(case.id, 5, 5) })
                local prey, other, cat = c.units[1], c.units[2], c.units[3]
                cat.lastTurnHits = Combat.tallyCount(cat, "hitDealt")
                hiddenTurn(c, cat)
                assert(Combat.useItem(c, cat, itemNamed(cat.char, "weapon_pounce"), prey.x, prey.y), "pounce")
                assert(not prey.alive, "the pounce downs its target")
                assert(Status.has(cat, "status_invisible") == case.kept,
                    case.id .. (case.kept and " stays hidden" or " is seen"))
                other.initiative = 50
                standUp(c, cat)
                assert(Status.has(cat, "status_invisible") == case.kept,
                    case.id .. (case.kept and " opens her next turn hidden despite the blood"
                        or " does not open its next turn hidden, having drawn blood"))
            end
        end,
    },

    -- ------------------------------------------------------------------------------ the counterplay
    {
        name = "a hidden cat is off every aim, but an area blast still lands and Witchlight lights it",
        fn = function()
            local c = Combat.new(board(), { walker(1, 1) }, { unit("character_sabertooth", 5, 5) })
            local cat = c.units[2]
            Status.apply(c, cat, "status_invisible")
            assert(Status.untargetable(cat), "hidden, it cannot be picked")
            local caught = false
            for _, u in ipairs(Combat.aoeUnits(c, { aoe = { shape = "square", radius = 1 } }, 5, 5, c.units[1])) do
                if u == cat then caught = true end
            end
            assert(caught, "an area blast collects it anyway")
            Status.apply(c, cat, "status_limned")
            assert(not Status.untargetable(cat), "and a lit cat is a target again")
        end,
    },
    {
        name = "Wood-Walker: rough ground costs the cat no more than open ground",
        fn = function()
            local c = Combat.new(board(), { walker(1, 1) }, { unit("character_sabertooth", 5, 5) })
            assert(Combat.terrainEase(c, c.units[2], 5, 5) == 1, "the most the ground may charge it is one")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "the Ambush Charm makes the weapon beside it a critical on a turn opened unseen, and only then",
        fn = function()
            local c = Combat.new(board(), { unit("character_archer", 5, 5, { isolate = "bare" }) },
                { unit("character_bandit", 5, 6, { isolate = "bare", stats = { health = 300 } }) })
            local hero, foe = c.units[1], c.units[2]
            local blade = Item.instantiate("weapon_iron_dagger")
            hero.char.inventory[1] = blade
            hero.char.inventory[2] = Item.instantiate("utility_ambush_charm")
            standUp(c, hero)
            assert(not Combat.forcesCrit(c, hero, foe, blade), "seen, the charm does nothing")
            Status.apply(c, hero, "status_invisible")
            standUp(c, hero)
            assert(Combat.critChance(c, hero, foe, blade) == 100, "opened unseen, the blade beside it is certain")
            hero.char.inventory[2], hero.char.inventory[9] = nil, Item.instantiate("utility_ambush_charm")
            assert(not Combat.forcesCrit(c, hero, foe, blade), "and a charm across the grid is not beside it")
        end,
    },
    {
        name = "the Stalker's Mantle: the first blow from a tile no foe can see, and not the second",
        fn = function()
            -- A wall of sight-blocking ground between the two rows.
            local walls = {}
            for x = 1, 9 do walls[#walls + 1] = { x = x, y = 5, sightCost = 9 } end
            local c = Combat.new(board(9, { tiles = walls }),
                { unit("character_archer", 5, 3, { isolate = "bare", items = { "armor_stalkers_mantle" } }) },
                { unit("character_bandit", 5, 7, { isolate = "bare", stats = { health = 300 } }) })
            local hero, foe = c.units[1], c.units[2]
            local bow = Item.instantiate("weapon_iron_bow")
            standUp(c, hero)
            assert(not Combat.seenByFoe(c, hero), "nothing can see the archer's tile")
            assert(Combat.forcesCrit(c, hero, foe, bow), "the first blow from cover is a critical")
            Combat.tally(hero, "hitDealt", 1)
            assert(not Combat.forcesCrit(c, hero, foe, bow), "the ambush is spent once a blow has landed")
            Combat.tally(hero, "hitDealt", -1)
            foe.x, foe.y = 5, 4
            assert(Combat.seenByFoe(c, hero) and not Combat.forcesCrit(c, hero, foe, bow),
                "a foe that can see you takes no ambush")
        end,
    },
    {
        name = "the Trophy Cord counts kinds, not kills, caps at +10, survives a save and empties at the Gate",
        fn = function()
            local hero = Character.instantiate("character_archer")
            local cord = Item.instantiate("utility_trophy_cord")
            hero.inventory[9] = cord
            local c = Combat.new(board(), { unit(hero, 5, 5, { isolate = "none" }) }, {
                unit("character_wolf_grunt", 1, 1), unit("character_wolf_grunt", 1, 3),
                unit("character_boar", 1, 5), unit("character_bear", 1, 7),
                unit("character_sabertooth", 9, 1), unit("character_manticore", 9, 3),
                unit("character_wyvern", 9, 5),
            })
            local u = c.units[1]
            local base = Combat.flatStat(u, "damage")
            local function fell(foe)
                Combat.dealFlatDamage(c, foe, 9999, { "physical" }, nil, u)
                assert(not foe.alive, "the blow fells it")
            end
            fell(c.units[2]); fell(c.units[3])
            assert(Combat.flatStat(u, "damage") == base + 2, "two wolves are one kind: +2")
            fell(c.units[4]); fell(c.units[5])
            assert(Combat.flatStat(u, "damage") == base + 6, "a boar and a bear make three kinds: +6")
            for i = 6, 8 do fell(c.units[i]) end
            assert(Combat.flatStat(u, "damage") == base + 10, "six kinds, and the cord stops at +10")

            local player = Player.new()
            player.roster = { hero }
            local back = Save.restore(Save.snapshot(player))
            local restored = back and back.roster and back.roster[1] and back.roster[1].inventory[9]
            assert(restored and restored.trophies and restored.trophies.character_boar,
                "the kinds taken this trip survive a save")

            Player.unpack(player)
            assert(cord.trophies == nil, "coming back through the Gate empties the cord")
        end,
    },
}
