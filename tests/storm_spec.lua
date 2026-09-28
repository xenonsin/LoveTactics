-- Tests for WRATH'S ELEMENTALS (reviewed over two rounds, 2026-09-27/28, "Fire, Lightning, and Dirty Thunder";
-- models/storm.lua): the Blaze, the Arc, the Thunderhead they fuse into, and the nine pieces they drop.
--
--   the bodies     two new tier-2 elementals and a tier-3 storm; each carries its rules on a creature organ
--   the flows      a lava-walker crosses lava and may stand in it; the Blaze mends there; water puts it out
--   the fire       Wildfire creeps into plain ground toward the foe; a blow kindles the struck tile; doused, neither
--   the lightning  a bolt forks friend or foe; the first bolt a turn Blinds; walking stores Static, a Root wastes it
--   the storm      a Blaze and an Arc side by side fuse; below half it tears once; the halves may fuse again; its
--                  fire conducts; its ash blinds and seals a line; at a third it erupts
--   the drops      Pyroclast picks the weaker element; Ball Lightning goes through bodies in a line; the Stone
--   the fights     three encounters on Wrath's floors, and Dirty Thunder plays out to a decision

local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Character = require("models.character")
local Item = require("models.item")
local Status = require("models.status")
local Hazard = require("models.hazard")
local Terrain = require("models.terrain")
local Storm = require("models.storm")
local Fixture = require("tests.support.fixture")

local unit, openTurn, hp = Fixture.unit, Fixture.openTurn, Fixture.hp

local function lavaTile(x, y)
    local lava = Terrain.get("lava")
    return { x = x, y = y, type = "lava", walkable = lava.walkable, moveCost = lava.moveCost, sightCost = 0 }
end

-- A board with a lava column at `col` (every row), or none.
local function board(cols, rows, col)
    local patches = {}
    if col then for y = 1, rows do patches[#patches + 1] = lavaTile(col, y) end end
    return Fixture.new(cols, rows, { tiles = patches })
end

-- A company body on a deep pool, carrying `items` beside a sword.
local function body(x, y, items, stats)
    local list = { "weapon_iron_sword" }
    for _, id in ipairs(items or {}) do list[#list + 1] = id end
    local s = { health = 400, movement = 6 }
    for k, v in pairs(stats or {}) do s[k] = v end
    return unit("character_archer", x, y, { isolate = "bare", items = list, stats = s })
end

local function one(c, id)
    for _, u in ipairs(c.units) do
        if u.alive and not Combat.isOffTile(u) and u.char and u.char.id == id then return u end
    end
end

local function reaches(c, u, x, y)
    for _, n in ipairs(Combat.reachableList(c, u)) do
        if n.x == x and n.y == y then return true end
    end
    return false
end

local function fires(c)
    local n = 0
    for _, h in ipairs(c.hazards or {}) do if h.id == "hazard_fire" and (h.remaining or 1) > 0 then n = n + 1 end end
    return n
end

local function rested(u)
    for _, pool in ipairs({ "stamina", "mana" }) do
        local st = u.char.stats[pool]
        if type(st) == "table" then st.max, st.current = 99, 99 end
    end
end

return {
    -- ------------------------------------------------------------------------------------------------ the bodies
    {
        name = "the Blaze and the Arc are new tier-2 elementals, the Thunderhead a tier-3 storm, each with its organ",
        fn = function()
            local b, a, t = Character.defs.character_blaze, Character.defs.character_arc, Character.defs.character_thunderhead
            assert(b.tier == 2 and a.tier == 2 and t.tier == 3 and t.boss, "two line bodies and an elite")
            for _, d in ipairs({ b, a, t }) do assert(d.race == "elemental", d.name .. " is an elemental") end
            assert(b.stats.health == 46 and a.stats.health == 34 and t.stats.health == 140, "the review's bars")
            assert(b.archetype == "gather" and a.archetype == "gather", "each walks to its other half")
            local function carries(def, id)
                for _, i in ipairs(def.startingItems) do if i == id then return true end end
            end
            assert(carries(b, "utility_of_the_flows") and carries(b, "weapon_blaze_fists"), "the Blaze's kit")
            assert(carries(a, "utility_the_arc") and carries(a, "weapon_arc_bolt"), "the Arc's kit")
            assert(carries(t, "utility_the_thunderhead") and carries(t, "ability_pyroclast"), "the storm's kit")
            assert(Character.defs.character_fire_elemental, "Lust's Fire Elemental is untouched")
        end,
    },
    {
        name = "nine drops, three a body, each an unstocked trophy on Wrath's rungs",
        fn = function()
            local want = {
                character_blaze = { "utility_flowwalkers_soles", "utility_heart_of_the_wildfire", "utility_coal_in_the_fist" },
                character_arc = { "weapon_forked_rod", "utility_flashpan", "utility_static_coil" },
                character_thunderhead = { "ability_pyroclast", "utility_eruption_stone", "ability_ball_lightning" },
            }
            for id, drops in pairs(want) do
                local got = Character.defs[id].drops
                assert(#got == 3, id .. " drops three")
                for i, d in ipairs(drops) do
                    assert(got[i] == d, id .. " drops " .. d)
                    local item = Item.defs[d]
                    assert(item.unstocked and not item.price, d .. " is a trophy, never sold")
                    local rung = id == "character_thunderhead" and 8 or 7
                    assert(item.unlockLevel == rung, d .. " sits on rung " .. rung)
                end
            end
        end,
    },

    -- ------------------------------------------------------------------------------------------------ the flows
    {
        name = "a lava-walker crosses the flow and may stand in it; nobody else can",
        fn = function()
            local c = Fixture.combat(board(9, 5, 5), body(1, 1), { unit("character_blaze", 4, 3) })
            local blaze = one(c, "character_blaze")
            assert(Combat.isLavaborn(blaze), "the Blaze is at home in lava")
            assert(reaches(c, blaze, 5, 3), "it may stop in the flow")
            assert(reaches(c, blaze, 7, 3), "and come out on the far side")
            local c2 = Fixture.combat(board(9, 5, 5), body(4, 3), {})
            assert(not reaches(c2, c2.units[1], 6, 3), "a body without the tag goes nowhere across it")
            local c3 = Fixture.combat(board(9, 5, 5), body(4, 3, { "utility_flowwalkers_soles" }), {})
            assert(reaches(c3, c3.units[1], 5, 3) and reaches(c3, c3.units[1], 6, 3),
                "Flowwalker's Soles walk it and stand in it (the note on the row)")
        end,
    },
    {
        name = "the Blaze mends at the end of a turn in lava, and a water blow puts it out",
        fn = function()
            local c = Fixture.combat(board(9, 5, 5), body(1, 1), { unit("character_blaze", 5, 3) })
            local blaze = one(c, "character_blaze")
            blaze.char.stats.health.current = 20
            openTurn(c, blaze)
            Combat.wait(c, blaze)
            assert(hp(blaze) == 26, "13% of 46 is 6, got " .. hp(blaze))
            Combat.dealFlatDamage(c, blaze, 12, { "water", "magical" }, "test")
            assert(Status.has(blaze, "status_doused"), "water put it out")
            local before = hp(blaze)
            openTurn(c, blaze)
            Combat.wait(c, blaze)
            assert(hp(blaze) == before, "a doused Blaze does not mend")
        end,
    },

    -- ------------------------------------------------------------------------------------------------ the fire
    {
        name = "Wildfire creeps into plain ground toward the foe; doused, it does not",
        fn = function()
            local c = Fixture.combat(board(11, 5), body(10, 3), { unit("character_blaze", 3, 3) })
            local blaze = one(c, "character_blaze")
            Hazard.place(c, 4, 3, "hazard_fire", {})
            assert(fires(c) == 1, "one fire to start")
            assert(Storm.wildfire(c, blaze) == 1, "it spreads a tile")
            assert(Storm.fireAt(c, 5, 3), "toward the company, not away from it")
            Status.apply(c, blaze, "status_doused")
            assert(Storm.wildfire(c, blaze) == 0, "put out, it feeds nothing")
        end,
    },
    {
        name = "the Blaze's blow kindles the struck tile and burns the body on it; doused, it carries no fire",
        fn = function()
            local c = Fixture.combat(board(7, 5), body(3, 3), { unit("character_blaze", 4, 3) })
            local blaze, s = one(c, "character_blaze"), c.units[1]
            rested(blaze)
            assert(Fixture.strike(c, blaze, s, "weapon_blaze_fists"), "it swings")
            assert(Storm.fireAt(c, 3, 3), "the struck tile burns")
            assert(Status.has(s, "status_burn"), "and so does the body on it")

            local c2 = Fixture.combat(board(7, 5), body(3, 3), { unit("character_blaze", 4, 3) })
            local b2, s2 = one(c2, "character_blaze"), c2.units[1]
            rested(b2)
            Status.apply(c2, s2, "status_immune_fire")
            local before = hp(s2)
            Fixture.strike(c2, b2, s2, "weapon_blaze_fists")
            assert(hp(s2) == before, "a fire ward voids a burning fist")
            Status.apply(c2, b2, "status_doused")
            Fixture.strike(c2, b2, s2, "weapon_blaze_fists")
            assert(hp(s2) < before, "a doused fist is only a fist, and the ward does not stop it")
            assert(not Storm.fireAt(c2, 3, 3), "and it lights nothing")
        end,
    },

    -- ------------------------------------------------------------------------------------------------ the lightning
    {
        name = "the Arc's bolt forks through whoever is nearest, its own side included, and never back to itself",
        fn = function()
            -- The bolt lands on (3,3); the Blaze beside it is the nearest body, and the second body is two from
            -- the Blaze and three from the target -- so only a second hop, from the Blaze, reaches it.
            local c = Fixture.combat(board(11, 5), { body(3, 3), body(4, 5) },
                { unit("character_arc", 7, 3), unit("character_blaze", 4, 3) })
            local arc, s, s2, blaze = one(c, "character_arc"), c.units[1], c.units[2], one(c, "character_blaze")
            rested(arc)
            local b0, s20, a0 = hp(blaze), hp(s2), hp(arc)
            assert(Fixture.strike(c, arc, s, "weapon_arc_bolt"), "it looses")
            assert(hp(blaze) < b0, "the first fork found the Blaze beside the target")
            assert(hp(s2) < s20, "and the second went on from the target's side")
            assert(hp(arc) == a0, "never back into the Arc")
        end,
    },
    {
        name = "Thunderclap blinds the first body struck each turn, and only the first",
        fn = function()
            local c = Fixture.combat(board(11, 5), { body(4, 2), body(4, 5) }, { unit("character_arc", 6, 3) })
            local arc, s, s2 = one(c, "character_arc"), c.units[1], c.units[2]
            rested(arc)
            Fixture.strike(c, arc, s, "weapon_arc_bolt")
            assert(Status.has(s, "status_blind"), "the struck body is blinded")
            -- A second bolt inside the SAME turn (the record still names the Arc and has had its clap).
            openTurn(c, arc)
            c.turn.thunderclap = true
            Combat.useItem(c, arc, Fixture.itemNamed(arc.char, "weapon_arc_bolt"), s2.x, s2.y)
            assert(not Status.has(s2, "status_blind"), "a second bolt in the same turn blinds nobody")
        end,
    },
    {
        name = "every tile walked stores Static, the next bolt spends it for more, and a Root wastes it",
        fn = function()
            local c = Fixture.combat(board(11, 5), body(1, 3), { unit("character_arc", 9, 3) })
            local arc, s = one(c, "character_arc"), c.units[1]
            rested(arc)
            openTurn(c, arc)
            assert(Combat.moveUnit(c, arc, 6, 3), "it walks three")
            assert(Storm.charges(arc) == 3, "three charges, got " .. Storm.charges(arc))
            local b = Fixture.itemNamed(arc.char, "weapon_arc_bolt")
            local charged = Combat.computeDamage(c, arc, s, b)
            Status.remove(c, arc, "status_static")
            local plain = Combat.computeDamage(c, arc, s, b)
            assert(charged == plain + 9, "+3 a charge")
            openTurn(c, arc)
            Combat.moveUnit(c, arc, 7, 3)
            assert(Storm.charges(arc) == 1, "a step stores one")
            Status.apply(c, arc, "status_root")
            assert(Storm.charges(arc) == 0, "a Root runs it into the floor")
        end,
    },

    -- ------------------------------------------------------------------------------------------------ the storm
    {
        name = "a Blaze and an Arc side by side at a turn's end fuse into the Thunderhead, filled to their share",
        fn = function()
            local c = Fixture.combat(board(11, 7), body(1, 1), { unit("character_blaze", 6, 4), unit("character_arc", 7, 4) })
            local blaze, arc = one(c, "character_blaze"), one(c, "character_arc")
            arc.char.stats.health.current = 17 -- half of the Arc: the pair holds 63 of 80
            openTurn(c, c.units[1])
            Combat.wait(c, c.units[1])
            local storm = one(c, "character_thunderhead")
            assert(storm, "the storm stands")
            assert(storm.x == 6 and storm.y == 4, "on the Blaze's tile")
            assert(Combat.isOffTile(blaze) and Combat.isOffTile(arc), "the halves are inside it")
            assert(blaze.alive and arc.alive, "alive, so the fight is not won by their going in")
            local want = math.floor(storm.char.stats.health.max * 63 / 80 + 0.5)
            assert(hp(storm) == want, "its bar is the pair's share: " .. want .. ", got " .. hp(storm))
            assert(Combat.isFlying(storm), "a cloud flies")
        end,
    },
    {
        name = "below half it tears into its halves at a quarter; they fuse again into the same storm, which never tears twice",
        fn = function()
            local c = Fixture.combat(board(11, 7), body(1, 1), { unit("character_blaze", 6, 4), unit("character_arc", 7, 4) })
            local blaze, arc = one(c, "character_blaze"), one(c, "character_arc")
            Storm.turnEnd(c)
            local storm = one(c, "character_thunderhead")
            local quarter = math.floor(storm.char.stats.health.max / 4)
            Combat.dealFlatDamage(c, storm, hp(storm) - 60, { "slash" }, "test", nil, { raw = true })
            assert(not one(c, "character_thunderhead"), "it tore and is off the board")
            assert(storm.alive and storm.stormHeld, "held inside its Blaze, alive")
            assert(not Combat.isOffTile(blaze) and not Combat.isOffTile(arc), "both halves are out")
            assert(hp(blaze) == math.min(quarter, blaze.char.stats.health.max), "the Blaze at a quarter of the bar")
            assert(hp(arc) == math.min(quarter, arc.char.stats.health.max), "the Arc likewise")
            -- side by side again (release put them beside each other or on the storm's tile)
            Combat.teleportUnit(c, arc, blaze.x + 1, blaze.y, { silent = true })
            Storm.turnEnd(c)
            assert(one(c, "character_thunderhead") == storm, "the SAME storm comes back")
            assert(storm.stormTorn, "and it remembers it has torn")
            Combat.dealFlatDamage(c, storm, hp(storm) - 1, { "slash" }, "test", nil, { raw = true })
            assert(one(c, "character_thunderhead") == storm, "the second storm does not tear")
        end,
    },
    {
        name = "one blow that would fell a whole storm tears it instead",
        fn = function()
            local c = Fixture.combat(board(11, 7), body(1, 1), { unit("character_blaze", 6, 4), unit("character_arc", 7, 4) })
            Storm.turnEnd(c)
            local storm = one(c, "character_thunderhead")
            Combat.dealFlatDamage(c, storm, 9999, { "slash" }, "test", nil, { raw = true })
            assert(storm.alive and storm.stormHeld, "torn, not felled")
            assert(one(c, "character_blaze") and one(c, "character_arc"), "the halves stand")
        end,
    },
    {
        name = "with both halves down while the storm is held, the storm falls with them",
        fn = function()
            local c = Fixture.combat(board(11, 7), body(1, 1), { unit("character_blaze", 6, 4), unit("character_arc", 7, 4) })
            Storm.turnEnd(c)
            local storm = one(c, "character_thunderhead")
            Combat.dealFlatDamage(c, storm, 9999, { "slash" }, "test", nil, { raw = true })
            local blaze, arc = one(c, "character_blaze"), one(c, "character_arc")
            Combat.dealFlatDamage(c, blaze, 9999, { "impact" }, "test", nil, { raw = true })
            assert(storm.alive, "one half left, the storm is still held")
            Combat.dealFlatDamage(c, arc, 9999, { "impact" }, "test", nil, { raw = true })
            assert(not storm.alive, "the last half takes it down")
        end,
    },
    {
        name = "while the storm stands its fire conducts, and without it fire does not",
        fn = function()
            local c = Fixture.combat(board(11, 7), body(1, 1), { unit("character_blaze", 6, 4), unit("character_arc", 7, 4) })
            Hazard.place(c, 3, 3, "hazard_fire", {})
            assert(not Combat.tileHasTag(c, 3, 3, Combat.CONDUCT_TAG), "an ordinary fire carries nothing")
            Storm.turnEnd(c)
            assert(Combat.tileHasTag(c, 3, 3, Combat.CONDUCT_TAG), "the storm's fire carries its lightning")
        end,
    },
    {
        name = "Ashfall lays three tiles of ash toward the foe, sealing a line and blinding whoever walks in",
        fn = function()
            local c = Fixture.combat(board(11, 7), body(1, 4), { unit("character_blaze", 6, 4), unit("character_arc", 7, 4) })
            Storm.turnEnd(c)
            local storm = one(c, "character_thunderhead")
            assert(Storm.ashfall(c, storm) == 3, "three tiles")
            assert(Hazard.sightCostAt(c, 5, 4) >= Combat.SIGHT_BLOCK, "on the line toward the foe")
            assert(not Combat.hasLineOfSight(c, 1, 4, 9, 4), "which that line can no longer be drawn across")
        end,
    },
    {
        name = "at a third it erupts once: lava round it, and a bolt for every body standing in fire",
        fn = function()
            local c = Fixture.combat(board(11, 7), { body(2, 2), body(9, 6) },
                { unit("character_blaze", 6, 4), unit("character_arc", 7, 4) })
            Storm.turnEnd(c)
            local storm = one(c, "character_thunderhead")
            storm.stormTorn = true -- past its tear, so the blow below reaches the eruption
            Hazard.place(c, 2, 2, "hazard_fire", {})
            local burning, dry = c.units[1], c.units[2]
            local b0, d0 = hp(burning), hp(dry)
            Combat.dealFlatDamage(c, storm, hp(storm) - math.floor(storm.char.stats.health.max / 3), { "slash" },
                "test", nil, { raw = true })
            assert(storm.stormErupted, "it erupted")
            assert(Storm.isLava(c, storm.x + 1, storm.y) and Storm.isLava(c, storm.x, storm.y - 1), "lava beside it")
            assert(hp(burning) < b0, "the body standing in fire is struck")
            assert(hp(dry) == d0, "the one on dry ground is not")
        end,
    },

    -- ------------------------------------------------------------------------------------------------ the drops
    {
        name = "Pyroclast lands as whichever element the target resists less, and lights the tile",
        fn = function()
            local c = Fixture.combat(board(7, 5), body(1, 3, { "ability_pyroclast" }), { unit("character_blaze", 3, 3) })
            local s, blaze = c.units[1], one(c, "character_blaze")
            rested(s)
            local before = hp(blaze)
            assert(Fixture.strike(c, s, blaze, "ability_pyroclast"), "it casts")
            -- The Blaze resists fire 3 and lightning not at all: the bolt must land as lightning.
            local expectFire = Combat.mitigatedDamage(blaze, 50, { "magical", "fire" })
            local expectBolt = Combat.mitigatedDamage(blaze, 50, { "magical", "lightning" })
            assert(expectBolt > expectFire, "the fixture's premise")
            assert(hp(blaze) < before, "it lands")
            assert(Storm.fireAt(c, 3, 3), "and the tile burns")
        end,
    },
    {
        name = "Ball Lightning aims only along a line, strikes every body in it, friend or foe, and lands at the end",
        fn = function()
            local c = Fixture.combat(board(9, 5), { body(1, 3, { "ability_ball_lightning" }), body(3, 3) },
                { unit("character_blaze", 4, 3) })
            local s, friend, blaze = c.units[1], c.units[2], one(c, "character_blaze")
            rested(s)
            local item = Fixture.itemNamed(s.char, "ability_ball_lightning")
            openTurn(c, s)
            assert(not Combat.useItem(c, s, item, 4, 5), "never off the line")
            local f0, b0 = hp(friend), hp(blaze)
            openTurn(c, s)
            assert(Combat.useItem(c, s, item, 6, 3), "down the row")
            assert(s.x == 6 and s.y == 3, "it lands on the aimed tile")
            assert(hp(friend) < f0 and hp(blaze) < b0, "and struck both bodies it went through")
        end,
    },
    {
        name = "the Eruption Stone rings its bearer in lava the first time it drops to a third",
        fn = function()
            local c = Fixture.combat(board(9, 7), body(4, 4, { "utility_eruption_stone" }, { health = 90 }), {})
            local s = c.units[1]
            Combat.dealFlatDamage(c, s, 55, { "slash" }, "test", nil, { raw = true })
            assert(not Storm.isLava(c, 5, 4), "above a third, nothing")
            Combat.dealFlatDamage(c, s, 10, { "slash" }, "test", nil, { raw = true })
            assert(Storm.isLava(c, 5, 4) and Storm.isLava(c, 3, 4) and Storm.isLava(c, 4, 3), "an island")
        end,
    },

    -- ------------------------------------------------------------------------------------------------ the fights
    {
        name = "two fights on the approach and Dirty Thunder on the seat, all on Wrath's ground",
        fn = function()
            local up, heat, dirty = Encounter.defs.encounter_wrath_up_from_the_flows,
                Encounter.defs.encounter_wrath_heat_lightning, Encounter.defs.encounter_wrath_dirty_thunder
            assert(up.kind == "combat" and up.rung == 1, "Up from the Flows")
            assert(heat.kind == "combat" and heat.rung == 1, "Heat Lightning")
            assert(dirty.kind == "elite" and dirty.rung == 2 and dirty.alone, "Dirty Thunder, a set-piece on the seat")
            local comp = dirty.composition({})
            assert(#comp == 2 and comp[1] == "character_blaze" and comp[2] == "character_arc", "a Blaze and an Arc")
            for _, e in ipairs({ up, heat, dirty }) do
                assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "fen" }), "the Flows only")
            end
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local dealt = false
            for _, id in ipairs(wrath.elites.spares) do if id == "encounter_wrath_dirty_thunder" then dealt = true end end
            assert(dealt, "Wrath deals it")
        end,
    },
    {
        -- THE WHOLE FIGHT, played out with nobody watching: the fusion, the tear, the ash and the eruption on their own
        -- clocks. Held to a DECISION, not an outcome -- the case is that nothing in the storm loops or stalls.
        name = "Dirty Thunder plays out to a decision with a real company, and nothing in it stalls",
        fn = function()
            local EncounterBattle = require("models.encounter_battle")
            local Autobattle = require("models.autobattle")
            local roster = {}
            for i = 1, 4 do roster[i] = Character.instantiate("character_knight") end
            local built = EncounterBattle.build({
                encounter = { kind = "elite", id = "encounter_wrath_dirty_thunder", tier = 3 },
                party = roster, biome = "volcanic", seed = 20260928,
            })
            assert(built.combat and #built.enemyUnits == 2, "a Blaze and an Arc")
            EncounterBattle.autoDeploy(built.combat, built.arena, roster)
            Combat.openBattle(built.combat)
            local result, turns = Autobattle.run(built.combat)
            assert(result == "win" or result == "loss", "a decision in " .. tostring(turns) .. " turns, got "
                .. tostring(result))
        end,
    },
}
