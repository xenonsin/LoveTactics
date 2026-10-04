-- Tests for SLICE C of "Sloth's Bestiary" (2026-10-04): the Bog-Bound, the Frost Worm and the Noonday Demon, on
-- the tundra's approach (and one seat fight).
--
--   the Bog-Bound        Past Feeling -- a blow of 8 damage or less does nothing, the threshold on the badge; and
--                        the Mire Holds -- a body that starts its turn beside one pays 2 movement to step away,
--                        while a shove pays nothing. The Cairn-Keeper's Deeper Peat doubles both within 3.
--   the Frost Worm       the Trill sleeps every body in a ring of 4 when it lands, either side, every other turn;
--                        its bite Freezes a sleeper; its death Freezes everything within 2
--   the Noonday Demon    a foe within 4 that ends its turn having dealt no damage grows Listless (-3 Damage a
--                        stack); at 3 its next turn is Shamed; dealing damage clears it -- and a blow Past Feeling
--                        swallowed dealt nothing
--
-- Each case pins a rule the review approved, on a bare board, plus the drops and the fights' rungs.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local SlothBog = require("models.sloth_bog")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_bog_body = { race = "undead", tier = 2, organ = "utility_bog_bound",
        drop = "weapon_peat_black_spear", class = "sentinel" },
    character_cairn_keeper = { race = "undead", tier = 2, organ = "utility_deeper_peat",
        drop = "utility_cairn_stone", class = "warlord" },
    character_frost_worm = { race = "beast", tier = 3, organ = "utility_rime_gut",
        drop = "ability_worms_trill", class = "shaman" },
    character_noonday_demon = { race = "demon", tier = 3, organ = "utility_noonday_haze",
        drop = "utility_meridian_charm", class = "inquisitor" },
}
local OWN = { "weapon_bog_spear", "weapon_grave_cold", "weapon_frost_worm_bite", "ability_the_trill",
    "weapon_heat_of_the_day" }
local FIGHTS = {
    encounter_sloth_the_peat_line = { rung = 1, lead = "character_cairn_keeper", rest = "character_bog_body", n = 3 },
    encounter_sloth_the_trill = { rung = 1, lead = "character_frost_worm", rest = "character_bog_body", n = 2 },
    encounter_sloth_past_caring = { rung = 1, lead = "character_noonday_demon", rest = "character_bog_body", n = 3 },
    encounter_sloth_the_deep_cold = { rung = 2, lead = "character_frost_worm", rest = "character_ice_elemental", n = 2 },
}

local function board() return Fixture.new(11, 11) end

local function walker(x, y)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = 200, 200
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function hit(c, target, amount, attacker)
    return Combat.dealFlatDamage(c, target, amount, { "physical" }, "test", attacker, { raw = true })
end

-- A foe's turn, ended: the clock moves on (so last turn's blood is last turn's) and the field hears it end.
local function endTurnOf(c, u)
    c.turnCount = (c.turnCount or 0) + 1
    Trait.onAnyTurnEnd(c, u)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "four bodies, each with its organ and its trophy on a real shelf at the approach's rung",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == want.race, id .. " is " .. want.race)
                assert(def.tier == want.tier, id .. " stands on tier " .. want.tier)
                local c = Character.instantiate(id)
                assert(itemNamed(c, want.organ), id .. " carries " .. want.organ)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
                local drop = Item.defs[want.drop]
                assert(drop.class == want.class, want.drop .. " is " .. want.class .. " stock")
                assert(drop.unstocked and not drop.price, want.drop .. " is a trophy: on the rack, never sold")
                assert(drop.unlockLevel == 9, want.drop .. " sits at the approach's rung")
                local organ = Item.defs[want.organ]
                assert(organ.class == "creature" and organ.noSteal and organ.bound, want.organ .. " is a body's own")
            end
            for _, id in ipairs({ "character_bog_body", "character_cairn_keeper" }) do
                assert(itemNamed(Character.instantiate(id), "utility_bog_bound"), id .. " is one of the Bog-Bound")
            end
            for _, id in ipairs(OWN) do
                assert(Item.defs[id] and Item.defs[id].class == "creature", id .. " is a body's own")
            end
        end,
    },
    {
        name = "three approach fights and one seat fight stand on the tundra, ordinary traffic at weight 3",
        fn = function()
            for id, want in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == "combat", id .. " is ordinary traffic")
                assert(e.rung == want.rung, id .. " is homed on rung " .. want.rung)
                assert(e.weight == 3, id .. " weighs 3")
                assert(e.condition({ biome = "tundra" }) and not e.condition({ biome = "desert" }), id .. " is tundra-locked")
                local list = e.composition({ biome = "tundra", rung = want.rung })
                assert(list[1] == want.lead, id .. " is led by " .. want.lead)
                local n = 0
                for _, body in ipairs(list) do if body == want.rest then n = n + 1 end end
                assert(n == want.n, id .. " fields " .. want.n .. " of " .. want.rest .. " at its centre, got " .. n)
            end
        end,
    },
    -- ------------------------------------------------------------------------------ the Bog-Bound
    {
        name = "Past Feeling: a blow of 8 or less does nothing, anything heavier lands in full, and the badge says 8",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_bog_body", 5, 5) })
            local foe, bog = c.units[1], one(c, "character_bog_body")
            local badge = Status.get(bog, SlothBog.BADGE)
            assert(badge and badge.magnitude == 8 and badge.def.badgeCount, "the threshold is printed on the badge")
            local before = hp(bog)
            assert(hit(c, bog, 8, foe) == 0 and hp(bog) == before, "8 does nothing")
            assert(hit(c, bog, 9, foe) == 9 and hp(bog) == before - 9, "9 lands in full")
            assert(SlothBog.pastFeeling(bog, 8) == 0 and SlothBog.pastFeeling(bog, 12) == 12, "the forecast agrees")
        end,
    },
    {
        name = "Deeper Peat: within 3 of a Cairn-Keeper the threshold is 16, and a Sundered Keeper deepens nothing",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1),
                { unit("character_bog_body", 5, 5), unit("character_cairn_keeper", 5, 8) })
            local foe, bog, keeper = c.units[1], one(c, "character_bog_body"), one(c, "character_cairn_keeper")
            assert(SlothBog.threshold(bog) == 16, "three tiles from the Keeper: 16")
            assert(Status.get(bog, SlothBog.BADGE).magnitude == 16, "and the badge reads it")
            assert(SlothBog.threshold(keeper) == 16, "the Keeper stands in its own reach")
            local before = hp(bog)
            hit(c, bog, 16, foe)
            assert(hp(bog) == before, "16 does nothing")
            hit(c, bog, 17, foe)
            assert(hp(bog) == before - 17, "17 lands in full")
            keeper.x, keeper.y = 5, 9
            assert(SlothBog.threshold(bog) == 8, "four tiles off, the peat is shallow again")
            keeper.x, keeper.y = 5, 8
            Status.apply(c, keeper, "status_sundered", {})
            assert(SlothBog.threshold(bog) == 8, "breaking the Keeper breaks the peat")
        end,
    },
    {
        name = "the Mire Holds: starting beside one, the step away costs 2 more; a shove pays nothing",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 5), { unit("character_bog_body", 5, 4) })
            local held = c.units[1]
            openTurn(c, held)
            local reach = Combat.reachable(c, held)
            local away = reach["5,6"]
            assert(away and away.cost == 3, "one step away costs 1 + 2, got " .. tostring(away and away.cost))
            assert(reach["5,7"] == nil, "and the walker's 3 movement is spent on it")
            -- A body that did not START beside it walks past for nothing.
            local c2 = Fixture.combat(board(), walker(5, 7), { unit("character_bog_body", 5, 4) })
            local free = c2.units[1]
            openTurn(c2, free)
            local r2 = Combat.reachable(c2, free)
            assert(r2["6,5"] and r2["6,5"].cost == 3, "up beside it and off again, untolled")
            -- A shove is not a step.
            local bog = one(c, "character_bog_body")
            Combat.knockback(c, bog, held, 1)
            assert(held.y == 6, "the shove carries it off without asking the mire")
        end,
    },
    {
        name = "Deeper Peat doubles the toll to 4: beside a Bog-Bound near the Keeper, a walker of 3 cannot leave",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 5),
                { unit("character_bog_body", 5, 4), unit("character_cairn_keeper", 5, 2) })
            local held = c.units[1]
            openTurn(c, held)
            local reach = Combat.reachable(c, held)
            assert(next(reach) == nil, "every step away costs 1 + 4")
        end,
    },
    {
        name = "the Peat-Black Spear strikes a foe that ends its turn in its two-tile line, and nobody else",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_archer", 5, 5, { isolate = "bare", items = { "weapon_peat_black_spear" } }),
                { walker(5, 7), walker(6, 6), walker(5, 9) })
            local inLine, diagonal, far = c.units[2], c.units[3], c.units[4]
            local a, d, f = hp(inLine), hp(diagonal), hp(far)
            endTurnOf(c, inLine); endTurnOf(c, diagonal); endTurnOf(c, far)
            assert(hp(inLine) < a, "two tiles down the line: struck")
            assert(hp(diagonal) == d, "off the line: not")
            assert(hp(far) == f, "three tiles: out of reach")
        end,
    },
    {
        name = "the Cairn Stone: allies within 3 cannot be moved, Charmed or Taunted; one further off can",
        fn = function()
            local c = Fixture.combat(board(),
                { unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_cairn_stone" } }),
                  walker(5, 8), walker(5, 10) },
                walker(1, 1))
            local bearer, near, far, foe = c.units[1], c.units[2], c.units[3], c.units[4]
            assert(Status.blocksForcedMove(bearer) and Status.blocksForcedMove(near), "the stone holds them")
            assert(not Status.blocksForcedMove(far), "five tiles off, it does not")
            assert(Status.apply(c, near, "status_charm", { applier = foe }) == nil, "no Charm within 3")
            assert(Status.apply(c, near, "status_taunt", { applier = foe }) == nil, "no Taunt within 3")
            assert(Status.apply(c, far, "status_taunt", { applier = foe }) ~= nil, "a Taunt lands further off")
        end,
    },
    -- ------------------------------------------------------------------------------ the Frost Worm
    {
        name = "the Trill: a wind-up, and every body in a ring of 4 when it lands falls Asleep, on either side",
        fn = function()
            local c = Fixture.combat(board(), { walker(6, 9), walker(6, 11) },
                { unit("character_frost_worm", 6, 6), unit("character_bog_body", 7, 6) })
            local inRing, outside = c.units[1], c.units[2]
            local worm, bog = one(c, "character_frost_worm"), one(c, "character_bog_body")
            local trill = itemNamed(worm.char, "ability_the_trill")
            assert(trill.activeAbility.windup and trill.activeAbility.windup > 0, "a wind-up: the tell")
            assert(trill.activeAbility.aoe.radius == 4, "a ring of radius 4")
            openTurn(c, worm)
            assert(Combat.useItem(c, worm, trill, worm.x, worm.y))
            assert(worm.channel, "it rears")
            assert(not Status.has(inRing, "status_sleep"), "nothing sleeps until it lands")
            Combat.resolveChannel(c, worm)
            assert(Status.has(inRing, "status_sleep"), "three tiles off: Asleep")
            assert(Status.has(bog, "status_sleep"), "its own line sleeps too")
            assert(not Status.has(outside, "status_sleep"), "five tiles off: awake")
            assert(not Status.has(worm, "status_sleep"), "the worm does not sleep through its own song")
            assert(Combat.onCooldown(worm, Combat.castCooldownKey(trill)), "and it cannot trill again straight away")
        end,
    },
    {
        name = "a shove breaks the Trill, and nobody sleeps",
        fn = function()
            local c = Fixture.combat(board(), walker(6, 7), { unit("character_frost_worm", 6, 6) })
            local foe, worm = c.units[1], one(c, "character_frost_worm")
            openTurn(c, worm)
            Combat.useItem(c, worm, itemNamed(worm.char, "ability_the_trill"), worm.x, worm.y)
            Combat.knockback(c, foe, worm, 1)
            assert(not worm.channel, "the wind-up is broken")
            assert(not Status.has(foe, "status_sleep"), "and the note never lands")
        end,
    },
    {
        name = "the worm's bite Freezes a sleeper, and only a sleeper",
        fn = function()
            local c = Fixture.combat(board(), { walker(6, 7), walker(5, 6) }, { unit("character_frost_worm", 6, 6) })
            local sleeper, waking, worm = c.units[1], c.units[2], one(c, "character_frost_worm")
            Status.apply(c, sleeper, "status_sleep", {})
            Fixture.strike(c, worm, sleeper, "weapon_frost_worm_bite")
            assert(Status.has(sleeper, "status_freeze"), "bitten asleep: Frozen")
            Fixture.strike(c, worm, waking, "weapon_frost_worm_bite")
            assert(not Status.has(waking, "status_freeze"), "bitten awake: not")
        end,
    },
    {
        name = "Death Throes: when the worm dies every body within 2 is Frozen, and one at 3 is not",
        fn = function()
            local c = Fixture.combat(board(), { walker(6, 8), walker(6, 9) },
                { unit("character_frost_worm", 6, 6), unit("character_bog_body", 7, 6) })
            local close, safe = c.units[1], c.units[2]
            local worm, bog = one(c, "character_frost_worm"), one(c, "character_bog_body")
            hit(c, worm, 9999, close)
            assert(not worm.alive, "the worm is dead")
            assert(Status.has(close, "status_freeze"), "two tiles off: Frozen")
            assert(Status.has(bog, "status_freeze"), "on either side")
            assert(not Status.has(safe, "status_freeze"), "three tiles off: finished from a safe distance")
        end,
    },
    {
        name = "Worm's Trill: channelled, and every foe within 3 when it lands falls Asleep -- the shaman's own side does not",
        fn = function()
            local c = Fixture.combat(board(),
                { unit("character_archer", 6, 6, { isolate = "bare", items = { "ability_worms_trill" },
                    stats = { mana = 60 } }), walker(6, 7) },
                { walker(6, 9), walker(6, 10) })
            local shaman, ally, near, far = c.units[1], c.units[2], c.units[3], c.units[4]
            openTurn(c, shaman)
            assert(Combat.useItem(c, shaman, itemNamed(shaman.char, "ability_worms_trill"), shaman.x, shaman.y))
            assert(shaman.channel, "it is a wind-up")
            Combat.resolveChannel(c, shaman)
            assert(Status.has(near, "status_sleep"), "a foe at 3: Asleep")
            assert(not Status.has(far, "status_sleep"), "a foe at 4: awake")
            assert(not Status.has(ally, "status_sleep"), "an ally beside it: awake")
        end,
    },
    -- ------------------------------------------------------------------------------ the Noonday Demon
    {
        name = "Listless: a foe within 4 that ends its turn having dealt nothing weighs -3 a stack; one at 5 does not",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 9), walker(5, 10) }, { unit("character_noonday_demon", 5, 5) })
            local near, far = c.units[1], c.units[2]
            endTurnOf(c, near); endTurnOf(c, far)
            assert(Status.stacksOf(near, SlothBog.LISTLESS) == 1, "four tiles off: Listless")
            assert(Status.statBonus(near, "damage") == -3, "-3 Damage")
            assert(not Status.has(far, SlothBog.LISTLESS), "five tiles off: not")
            endTurnOf(c, near)
            assert(Status.statBonus(near, "damage") == -6, "-3 a stack")
        end,
    },
    {
        name = "at 3 Listless the next turn is Shamed -- no act, no move -- and the stacks are spent",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8), { unit("character_noonday_demon", 5, 5) })
            local idle = c.units[1]
            endTurnOf(c, idle); endTurnOf(c, idle); endTurnOf(c, idle)
            assert(Status.stacksOf(idle, SlothBog.LISTLESS) == 3, "three idle turns, three stacks")
            Status.onTurnStart(c, idle)
            local shamed = Status.get(idle, "status_shamed")
            assert(shamed and shamed.def.disablesActions and shamed.def.blocksMove, "its next turn is Shamed")
            assert(not Status.has(idle, SlothBog.LISTLESS), "and the stacks are spent")
            Status.onTurnEnd(c, idle)
            assert(not Status.has(idle, "status_shamed"), "for that turn only")
        end,
    },
    {
        name = "dealing damage clears every stack, and a turn that drew blood grows none",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8), { unit("character_noonday_demon", 5, 5) })
            local body, demon = c.units[1], one(c, "character_noonday_demon")
            endTurnOf(c, body); endTurnOf(c, body)
            assert(Status.stacksOf(body, SlothBog.LISTLESS) == 2)
            c.turnCount = c.turnCount + 1
            hit(c, demon, 10, body)
            assert(not Status.has(body, SlothBog.LISTLESS), "a wound dealt clears them all")
            Trait.onAnyTurnEnd(c, body)
            assert(not Status.has(body, SlothBog.LISTLESS), "and the turn it was dealt on is not idle")
        end,
    },
    {
        name = "a blow Past Feeling swallows dealt no damage, and the Demon counts it",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8),
                { unit("character_noonday_demon", 5, 5), unit("character_bog_body", 5, 9) })
            local body, bog = c.units[1], one(c, "character_bog_body")
            c.turnCount = 10
            hit(c, bog, 8, body)
            Trait.onAnyTurnEnd(c, body)
            assert(Status.stacksOf(body, SlothBog.LISTLESS) == 1, "chipping at the peat is doing nothing")
            c.turnCount = 11
            hit(c, bog, 9, body)
            assert(not Status.has(body, SlothBog.LISTLESS), "a blow that lands clears it")
            Trait.onAnyTurnEnd(c, body)
            assert(not Status.has(body, SlothBog.LISTLESS), "and the turn is not idle")
        end,
    },
    {
        name = "the Meridian Charm lays Listless on an idle foe within 3, stacking, and never shames",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_meridian_charm" } }),
                { walker(5, 8), walker(5, 9) })
            local near, far = c.units[2], c.units[3]
            endTurnOf(c, near); endTurnOf(c, far)
            assert(Status.stacksOf(near, SlothBog.LISTLESS) == 1, "three tiles off: Listless")
            assert(not Status.has(far, SlothBog.LISTLESS), "four tiles off: not")
            endTurnOf(c, near); endTurnOf(c, near)
            assert(Status.statBonus(near, "damage") == -9, "-3 a stack, to 3")
            Status.onTurnStart(c, near)
            assert(not Status.has(near, "status_shamed") and Status.stacksOf(near, SlothBog.LISTLESS) == 3,
                "the charm only weighs")
        end,
    },
}
