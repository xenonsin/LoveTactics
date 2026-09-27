-- Tests for THE MINOTAUR (Wrath's seat elite, reviewed over four rounds of "The Minotaur", 2026-09-26/27): one
-- beast, alone, in the maze it brings, fighting as a barbarian (models/labyrinth.lua).
--
--   the beast      a tier-3 body on the fighter table with the barbarian discipline; the approved kit; two drops
--   the labyrinth  the fight opens in a maze, the beast at its heart, and the board stays one board
--   the walls      the beast walks through them and they break; the company goes round
--   the shifts     the walls slide on its third turn, marked a turn ahead, and never cut the board in two
--   the run        a straight approach of two or more drives the struck body back a tile per two
--   the labrys     cleaves the arc in front and the arc behind
--   head down      below a third, or on a blow that would fell it from above: Fury, at 1 and unkillable
--   its turn       Reckless on the first; with its head down, a straight run at the nearest body

local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Character = require("models.character")
local Item = require("models.item")
local Status = require("models.status")
local Wall = require("models.wall")
local Labyrinth = require("models.labyrinth")
local Fixture = require("tests.support.fixture")

local unit, openTurn, hp = Fixture.unit, Fixture.openTurn, Fixture.hp

local function board(n) return Fixture.new(n or 11, n or 11) end

-- A living company body with a sword (and whatever else), on a fixed health pool and a long stride.
local function swordsman(x, y, items)
    local list = { "weapon_iron_sword" }
    for _, id in ipairs(items or {}) do list[#list + 1] = id end
    return unit("character_archer", x, y, { isolate = "bare", items = list, stats = { health = 300, movement = 6 } })
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function rested(u)
    local st = u.char.stats.stamina
    if type(st) == "table" then st.max, st.current = 99, 99 end
end

-- The beast in a corner (it sets itself at the heart) against `party`.
local function lair(party)
    local c = Fixture.combat(board(), party or swordsman(1, 1), { unit("character_minotaur", 11, 11) })
    return c, one(c, "character_minotaur")
end

local function mazeWalls(c)
    local out = {}
    for _, w in ipairs(c.walls or {}) do if w.alive and w.maze then out[#out + 1] = w end end
    return out
end

-- Tear every maze wall down, for a case that wants to lay its own.
local function razed(c)
    for _, w in ipairs(mazeWalls(c)) do w.alive = false end
end

return {
    -- ------------------------------------------------------------------------------------------------ the beast
    {
        name = "the Minotaur is one tier-3 body on the fighter table, a barbarian, carrying the approved kit",
        fn = function()
            local def = Character.defs["character_minotaur"]
            assert(def.tier == 3 and def.boss, "a tier-3 elite")
            assert(def.class == "fighter" and def.discipline == "barbarian", "a fighter with the barbarian discipline")
            local race = require("models.race").defs[def.race]
            assert(race.kind == "humanoid" and race.playable == false and not race.grants,
                "its race is a one-body record: humanoid so it may carry a shelf, never hired, no clan rule")
            assert(race.resist.impact == 2 and race.resist.pierce == -2, "a hide that takes a blow and a spear finds")
            local carried = {}
            for _, id in ipairs(def.startingItems) do if id then carried[id] = true end end
            for _, id in ipairs({ "weapon_labrys", "utility_bulls_brow", "utility_the_labyrinth",
                "ability_desperate_strike", "ability_reckless_stance", "ability_culling_stroke",
                "utility_adrenal_surge", "armor_unspent_heart" }) do
                assert(carried[id], "it carries " .. id)
            end
            assert(not carried["ability_fury"], "Fury is Head Down's, never a cast it spends early")
        end,
    },
    {
        name = "it drops the Labrys and Bull's Brow, unstocked trophies on floor eight's rung",
        fn = function()
            local drops = Character.defs["character_minotaur"].drops
            assert(#drops == 2 and drops[1] == "weapon_labrys" and drops[2] == "utility_bulls_brow", "two drops, final")
            local l, b = Item.defs["weapon_labrys"], Item.defs["utility_bulls_brow"]
            assert(l.unstocked and not l.price and l.unlockLevel == 8 and l.class == "barbarian", "the Labrys")
            assert(b.unstocked and not b.price and b.unlockLevel == 8 and b.class == "vanguard", "Bull's Brow")
        end,
    },
    {
        name = "the Labyrinth is a lone volcanic elite on the seat, and Wrath deals it",
        fn = function()
            local e = Encounter.defs["encounter_wrath_the_labyrinth"]
            assert(e.kind == "elite" and e.alone and e.rung == 2, "a lone elite on the seat")
            assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }), "in Wrath's flows")
            local comp = e.composition({})
            assert(#comp == 1 and comp[1] == "character_minotaur", "the beast alone")
            local seated
            for _, circle in ipairs(Descent.SINS) do
                if circle.id == "wrath" then
                    for _, id in ipairs(circle.elites.spares) do
                        if id == "encounter_wrath_the_labyrinth" then seated = true end
                    end
                end
            end
            assert(seated, "Wrath's spares include the Labyrinth")
        end,
    },

    -- ------------------------------------------------------------------------------------------- the labyrinth
    {
        name = "the fight opens in a maze, with the beast at the heart and the board still one board",
        fn = function()
            local c, m = lair()
            assert(m.x == 6 and m.y == 6, "set at the heart of an 11x11 board, got " .. m.x .. "," .. m.y)
            local walls = mazeWalls(c)
            assert(#walls >= 12, "a maze, not a scatter: " .. #walls .. " stones")
            assert(Labyrinth.connected(c), "every body can still reach every other")
            for _, w in ipairs(walls) do
                for _, u in ipairs(c.units) do
                    assert(math.max(math.abs(w.x - u.x), math.abs(w.y - u.y)) > 1,
                        "no stone walls a body in at the bell")
                end
            end
        end,
    },
    {
        name = "a stone that would cut the board in two is never laid",
        fn = function()
            -- A corridor one tile wide with a body at each end and the beast between: every stone on it would
            -- cut somebody off. (A stone sealing an EMPTY dead end is fine -- nobody is on the far side.)
            local map = Fixture.new(15, 3)
            for x = 1, 15 do map.tiles[1][x].walkable = false; map.tiles[3][x].walkable = false end
            local c = Fixture.combat(map, { swordsman(1, 2), swordsman(15, 2) }, { unit("character_minotaur", 3, 2) })
            assert(Labyrinth.connected(c), "the corridor is still open end to end")
            assert(#mazeWalls(c) == 0, "no stone was laid across the only way through")
        end,
    },

    -- ----------------------------------------------------------------------------------------------- the walls
    {
        name = "the beast walks through a wall and breaks it; the company cannot",
        fn = function()
            local c, m = lair(swordsman(6, 9))
            razed(c)
            local wall = Wall.place(c, 6, 5, "rubble", { side = m.side })
            openTurn(c, m)
            assert(Combat.reachable(c, m)["6,4"], "its route runs through the stone")
            assert(Combat.moveUnit(c, m, 6, 4), "it walks")
            assert(not wall.alive, "and the wall it walked through is broken")
            assert(m.x == 6 and m.y == 4, "it stands beyond")
            local s = c.units[1]
            local other = Wall.place(c, 6, 8, "rubble", { side = m.side })
            openTurn(c, s)
            local reach = Combat.reachable(c, s)
            assert(not reach["6,8"] and other.alive, "the company's route stops at the stone")
        end,
    },

    -- ---------------------------------------------------------------------------------------------- the shifts
    {
        name = "the walls slide on its third turn, marked a turn ahead, and the board stays whole",
        fn = function()
            local c, m = lair()
            local before = {}
            for _, w in ipairs(mazeWalls(c)) do before[w] = w.x .. "," .. w.y end
            Labyrinth.onTurnEnd(c, m)
            assert(not (c.labyrinth and c.labyrinth.pending), "nothing is marked on its first turn")
            Labyrinth.onTurnEnd(c, m)
            local pending = c.labyrinth and c.labyrinth.pending
            assert(pending and #pending.marks > 0, "its second turn marks where the walls will land")
            for _, h in ipairs(pending.marks) do assert(h.id == "hazard_shifting_stone", "a Shifting Stone mark") end
            Labyrinth.onTurnEnd(c, m)
            local moved = 0
            for w, at in pairs(before) do if w.alive and (w.x .. "," .. w.y) ~= at then moved = moved + 1 end end
            assert(moved > 0, "its third turn slides them")
            assert(not c.labyrinth.pending, "and the marks are spent")
            for _, h in ipairs(pending.marks) do assert(not h.alive, "every mark is taken up") end
            assert(Labyrinth.connected(c), "no slide cuts the board in two")
        end,
    },

    -- ------------------------------------------------------------------------------------------------- the run
    {
        name = "Bull's Brow: four tiles straight then a blow drives the foe back two",
        fn = function()
            local c = Fixture.combat(board(), swordsman(2, 2, { "utility_bulls_brow" }),
                { unit("character_archer", 2, 7, { isolate = "bare", stats = { health = 300 } }) })
            local s, foe = c.units[1], c.units[2]
            rested(s)
            openTurn(c, s)
            assert(Combat.moveUnit(c, s, 2, 6), "a straight run of four")
            assert(c.turn.runLine == 4, "the turn counts the straight stretch: " .. tostring(c.turn.runLine))
            local ok = Combat.useItem(c, s, Fixture.itemNamed(s.char, "weapon_iron_sword"), foe.x, foe.y)
            assert(ok, "the blow lands")
            assert(foe.x == 2 and foe.y == 9, "driven back two, to (2,9), got " .. foe.x .. "," .. foe.y)
        end,
    },
    {
        name = "a single step is not a run, and a corner restarts the count",
        fn = function()
            local c = Fixture.combat(board(), swordsman(2, 5, { "utility_bulls_brow" }),
                { unit("character_archer", 2, 7, { isolate = "bare", stats = { health = 300 } }) })
            local s, foe = c.units[1], c.units[2]
            rested(s)
            openTurn(c, s)
            assert(Combat.moveUnit(c, s, 2, 6), "one step")
            Combat.useItem(c, s, Fixture.itemNamed(s.char, "weapon_iron_sword"), foe.x, foe.y)
            assert(foe.y == 7, "a step is not a run: the foe stands")
            -- A walk that turns: three east, then two south -- the run is the two after the corner.
            local c2 = Fixture.combat(board(), swordsman(1, 1, { "utility_bulls_brow" }),
                { unit("character_archer", 4, 4, { isolate = "bare", stats = { health = 300 } }) })
            local s2 = c2.units[1]
            rested(s2)
            openTurn(c2, s2)
            local path = { { x = 1, y = 1 }, { x = 2, y = 1 }, { x = 3, y = 1 }, { x = 4, y = 1 },
                { x = 4, y = 2 }, { x = 4, y = 3 } }
            local plan = assert(Combat.planMoveVia(c2, s2, path), "the steered route is legal")
            local walk = Combat.beginMove(c2, plan)
            while Combat.stepMove(c2, walk) do end
            assert(c2.turn.runLine == 2, "only the stretch after the corner counts: " .. tostring(c2.turn.runLine))
        end,
    },
    {
        name = "the Run's distance: one per two, up to three; with its head down one per tile, up to five",
        fn = function()
            local c, m = lair()
            assert(Labyrinth.runDistance(m, 1) == 0 and Labyrinth.runDistance(m, 2) == 1, "two tiles, one back")
            assert(Labyrinth.runDistance(m, 7) == 3, "capped at three")
            Status.apply(c, m, "status_head_down")
            assert(Labyrinth.runDistance(m, 2) == 2 and Labyrinth.runDistance(m, 9) == 5, "a tile per tile, to five")
        end,
    },

    -- ---------------------------------------------------------------------------------------------- the labrys
    {
        name = "the Labrys cleaves the arc in front and the same arc behind",
        fn = function()
            local c = Fixture.combat(board(), swordsman(6, 6, { "weapon_labrys" }), {})
            local s = c.units[1]
            local ab = Item.defs["weapon_labrys"].activeAbility
            local cells = {}
            for _, cell in ipairs(Combat.aoeCells(c, ab, 6, 5, s)) do cells[cell.x .. "," .. cell.y] = true end
            for _, k in ipairs({ "5,5", "6,5", "7,5", "5,7", "6,7", "7,7" }) do
                assert(cells[k], "the arc covers " .. k)
            end
            assert(not cells["6,6"], "never the wielder's own tile")
        end,
    },

    -- ----------------------------------------------------------------------------------------------- head down
    {
        name = "below a third it puts its head down: Fury, at 1 health, and +1 movement",
        fn = function()
            local c, m = lair()
            local max = Combat.unreservedMax(m.char, "health")
            local move = Combat.flatStat(m, "movement")
            Combat.dealFlatDamage(c, m, math.ceil(max * 0.7), { "physical" }, "test", nil, { raw = true })
            assert(m.alive, "it stands")
            assert(Status.has(m, "status_head_down") and Status.has(m, "status_fury"), "head down, and in Fury")
            assert(hp(m) == 1, "Fury drops it to 1")
            assert(Combat.flatStat(m, "movement") == move + 1, "a step further")
            Combat.dealFlatDamage(c, m, 9999, { "physical" }, "test", nil, { raw = true })
            assert(m.alive and hp(m) == 1, "and it cannot die while the Fury holds")
        end,
    },
    {
        name = "one blow that would fell it from above the line puts its head down instead",
        fn = function()
            local c, m = lair()
            Combat.dealFlatDamage(c, m, 9999, { "physical" }, "test", nil, { raw = true })
            assert(m.alive and hp(m) == 1, "it does not fall to the blow that skips the second phase")
            assert(Status.has(m, "status_fury") and m.headDown, "it goes into Fury")
        end,
    },

    -- ------------------------------------------------------------------------------------------------ its turn
    {
        name = "its first turn is Reckless Stance",
        fn = function()
            local c, m = lair()
            rested(m)
            openTurn(c, m)
            local plan = Labyrinth.plan(c, m)
            assert(plan and plan.reason == "reckless" and plan.item.id == "ability_reckless_stance", "it opens Reckless")
            local again = Labyrinth.plan(c, m)
            assert(not again or again.reason ~= "reckless", "it opens Reckless once")
        end,
    },
    {
        name = "with its head down it runs straight at the nearest body",
        fn = function()
            local c, m = lair(swordsman(6, 10))
            razed(c)
            m.openedReckless = true
            rested(m)
            Status.apply(c, m, "status_head_down")
            openTurn(c, m)
            local plan = assert(Labyrinth.plan(c, m), "it plans")
            assert(plan.reason == "head down", "head down")
            assert(plan.tx == 6 and plan.ty == 10, "at the nearest body")
            assert(plan.move and plan.move.x == 6 and plan.move.y == 9, "down the straight line to it")
        end,
    },
    {
        -- THE WHOLE FIGHT, played out with nobody watching: the maze laid, the beast's own planner driving it,
        -- the shifts and the Fury on their clocks. Held to a DECISION, not to an outcome -- the case is that
        -- nothing in the labyrinth loops or stalls the planner (a wall-walker, a sliding wall and a body that
        -- cannot die for four turns are three new ways to), not what the odds are.
        name = "the Labyrinth plays out to a decision with a real company, and nothing in it stalls",
        fn = function()
            local EncounterBattle = require("models.encounter_battle")
            local Autobattle = require("models.autobattle")
            local roster = {}
            for i = 1, 4 do roster[i] = Character.instantiate("character_knight") end
            local built = EncounterBattle.build({
                encounter = { kind = "elite", id = "encounter_wrath_the_labyrinth", tier = 3 },
                party = roster, biome = "volcanic", seed = 20260927,
            })
            assert(built.combat and #built.enemyUnits == 1, "the beast, alone")
            EncounterBattle.autoDeploy(built.combat, built.arena, roster)
            Combat.openBattle(built.combat)
            assert(#mazeWalls(built.combat) > 0, "in its maze")
            local result, turns = Autobattle.run(built.combat)
            assert(result == "win" or result == "loss", "a decision in " .. tostring(turns) .. " turns, got "
                .. tostring(result))
        end,
    },
    {
        name = "a company body carrying none of this is never planned for",
        fn = function()
            local c = Fixture.combat(board(), swordsman(2, 2, { "utility_bulls_brow" }), {})
            assert(Labyrinth.plan(c, c.units[1]) == nil, "an AI rule binds nobody the player drives")
        end,
    },
}
