-- The objective pass (approved whole, 2026-10-21): the rift's fights stopped being nothing but kill-all.
-- This file holds the five new shapes to their rules, the foundations under them, and -- the case the
-- skirmish guard cannot run -- every authored objective fight to finishing when a real company plays it.
--
--   break   `assassinate` with `targets`: every named body down
--   escape  an enemy runner walks for its way out; clear of the board, it ends the fight and keeps its drop
--   rescue  a bound charge at the far end (`captive`), cut free by a body beside it, walked home
--   heaps   carry out N heaps of loose gold (or clear the field, if the dwarves got there first)
--   orKillAll  a reach or hold that clearing the field also wins
local Arena = require("models.arena")
local Combat = require("models.combat")
local Character = require("models.character")
local Delver = require("models.delver")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")
local Run = require("tests.support.objective_run")

-- A bare combat-like table, which is all Combat.outcomeFor reads (tests/objective_spec.lua's trick).
local function fake(units, objective)
    return { units = units, objective = objective, clock = 0, heldTicks = 0, waveState = {} }
end
local function body(side, id, x, y, alive)
    return { side = side, x = x or 1, y = y or 1, alive = alive ~= false,
             char = { id = id, name = id, stats = { health = { current = 10 } } } }
end

-- HOW LONG an objective fight may run, in the unit-turns models/autobattle.lua counts. Twice and a bit
-- the skirmish budget (22): a set-piece with a clock or a crossing in it is longer than a road fight by
-- construction, and what is guarded here is that it ENDS, at a length a sitting can hold.
local OBJECTIVE_TURN_BUDGET = 70

local function objectiveFights()
    local ids = {}
    for id, def in pairs(Encounter.defs) do
        local obj = def.objective
        if (def.kind == "combat" or def.kind == "elite") and obj
            and (obj.type ~= "killAll" or obj.waves or obj.escape or def.allies) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

return {
    { name = "a break is won when every named body is down, and not before", fn = function()
        local obj = { type = "assassinate", targets = { "egg", "lamp" } }
        local egg, lamp = body("enemy", "egg"), body("enemy", "lamp")
        local c = fake({ body("party", "hero"), egg, lamp, body("enemy", "kobold") }, obj)
        assert(Combat.evaluate(c) == nil, "both marks stand")
        egg.alive = false
        assert(Combat.evaluate(c) == nil, "one mark stands")
        lamp.alive = false
        assert(Combat.evaluate(c) == "win", "every mark down wins with a kobold still standing")
    end },

    { name = "a mark named by its class body finds it in whatever people it was fielded as", fn = function()
        assert(Combat.idMatches("character_adv_summoner@elf", "character_adv_summoner"))
        assert(Combat.idMatches("character_adv_summoner", "character_adv_summoner"))
        assert(not Combat.idMatches("character_adv_summoner_x", "character_adv_summoner"),
            "a prefix that is not a variant is not the mark")
        local c = fake({ body("party", "hero"), body("enemy", "character_adv_summoner@orc") },
            { type = "assassinate", target = "character_adv_summoner" })
        assert(Combat.evaluate(c) == nil, "the orc summoner is the summoner")
    end },

    { name = "heaps are won on the count, and a cleared field still ends the race", fn = function()
        local foe = body("enemy", "dwarf")
        local c = fake({ body("party", "hero"), foe }, { type = "heaps", count = 3 })
        assert(Combat.evaluate(c) == nil)
        c.heapsLooted = 3
        assert(Combat.evaluate(c) == "win", "three heaps carried out")
        c.heapsLooted = 1
        foe.alive = false
        assert(Combat.evaluate(c) == "win", "the dwarves pocketed the rest; killing them ends it")
    end },

    { name = "or clear them: a crossing nobody made is still won on an empty field", fn = function()
        local foe = body("enemy", "nio")
        local obj = { type = "reach", tiles = { { x = 9, y = 9 } }, orKillAll = true }
        local c = fake({ body("party", "hero"), foe }, obj)
        assert(Combat.evaluate(c) == nil)
        foe.alive = false
        assert(Combat.evaluate(c) == "win")
        obj.orKillAll = nil
        assert(Combat.evaluate(c) == nil, "without the clause an empty field is not a crossing")
    end },

    { name = "a runner on its way out gets away, ends the fight, and only a runner does", fn = function()
        local stag = body("enemy", "stag", 3, 1)
        local wolf = body("enemy", "wolf", 4, 1)
        local obj = { type = "killAll", escape = { who = "stag" }, escapeTiles = { { x = 3, y = 1 }, { x = 4, y = 1 } } }
        local c = fake({ body("party", "hero", 1, 8), stag, wolf }, obj)
        c.logEvent = nil
        Combat.settleObjective(c)
        assert(c.escaped == stag and stag.escaped and not stag.alive, "the stag on its tile is gone")
        assert(wolf.alive, "a wolf on the same edge is not a runner")
        assert(Combat.evaluate(c) == "win", "the fight is over")
        Combat.rout(c)
        assert(not wolf.alive and wolf.routed and not wolf.corpse, "the rest rout, leaving no corpse")
    end },

    { name = "a runner stops being one when it changes shape", fn = function()
        local stag = body("enemy", "spirit", 3, 1)
        local c = fake({ stag }, { type = "killAll", escape = { who = "stag" }, escapeTiles = { { x = 3, y = 1 } } })
        assert(not Combat.isRunner(c, stag))
        Combat.settleObjective(c)
        assert(stag.alive and not c.escaped, "the Vengeful Spirit fights to the end")
    end },

    { name = "a captive is cut free by a body beside it, and not by one two tiles off", fn = function()
        local cap = body("party", "delver", 5, 1)
        local hero = body("party", "hero", 5, 3)
        local c = fake({ cap, hero, body("enemy", "spider", 1, 1) },
            { type = "reach", captive = "delver", protect = "delver", who = "delver", tiles = { { x = 5, y = 8 } } })
        assert(Combat.isBoundCaptive(c, cap))
        assert(Combat.objectiveGround(c)[1].y == 1, "while bound the ground is the captive")
        Combat.settleObjective(c)
        assert(not c.captiveFreed, "two tiles off frees nobody")
        hero.y = 2
        Combat.settleObjective(c)
        assert(c.captiveFreed and not Combat.isBoundCaptive(c, cap), "beside it, it is cut free")
        assert(Combat.objectiveGround(c)[1].y == 8, "free, the ground is the way home")
        assert(require("models.ai").plan ~= nil)
    end },

    { name = "a stray delver is rolled off the fight's seed, and the objective names the body rolled", fn = function()
        local ids, obj = Delver.roll({ Delver.ID }, { type = "defend", protect = Delver.ID }, 77)
        assert(ids[1] ~= Delver.ID and Delver.isDelver(ids[1]), "rolled: " .. tostring(ids[1]))
        assert(obj.protect == ids[1], "the protect clause follows the roll")
        local again = Delver.roll({ Delver.ID }, nil, 77)
        assert(again[1] == ids[1], "one seed, one stranger")
        local def = Character.defs[ids[1]]
        assert(def and def.delver and def.archetype == "holdGround" and not def.hire,
            "the variant is a hire's body, posted, and not a hire")
        assert(Character.defs[Delver.ID], "the unrolled body is a real blueprint for a rating to read")
    end },

    { name = "the arena seats the rolled delver and hands the combat a matching objective", fn = function()
        local arena = Arena.build({ depth = 3, biome = "forest" }, {
            party = { "character_rowan" }, seed = 4242,
            composition = { "character_wolf_grunt", "character_wolf_grunt" },
            allies = { Delver.ID },
            objective = { type = "killAll", protect = Delver.ID },
        })
        assert(#arena.allies == 1 and Delver.isDelver(arena.allies[1].id) and arena.allies[1].id ~= Delver.ID)
        assert(arena.objective.protect == arena.allies[1].id)
    end },

    { name = "a rescue's crossing runs home, to the edge the company landed on", fn = function()
        local arena = Arena.build({ depth = 1, biome = "forest" }, {
            party = { "character_rowan" }, seed = 99,
            composition = { "character_wolf_grunt" },
            allies = { Delver.ID },
            objective = { type = "reach", captive = Delver.ID, who = Delver.ID, protect = Delver.ID, anchor = "far" },
        })
        local partyY = arena.party[1].y
        local goalY = arena.objective.tiles[1].y
        local allyY = arena.allies[1].y
        assert(math.abs(goalY - partyY) < math.abs(goalY - allyY),
            "the goal sits on the company's side and the captive on the far one")
    end },

    { name = "an objective fight is rated but never walked off", fn = function()
        local found
        for _, id in ipairs(objectiveFights()) do
            local def = Encounter.get(id)
            local cell = { encounter = { id = id, kind = def.kind } }
            assert(EncounterBattle.cellRated(cell), id .. " has a band and a Run Away percent")
            assert(not EncounterBattle.cellEligible(cell), id .. " is never auto-resolved")
            found = true
        end
        assert(found, "there are objective fights to check")
    end },

    { name = "a wave named for its sender stops when the sender does", fn = function()
        local Waves = require("models.waves")
        local horn = body("enemy", "horn")
        local c = fake({ body("party", "hero"), horn },
            { type = "killAll", waves = { { every = 10, unless = "horn", composition = { "x" } } } })
        c.clock = 0
        horn.alive = false
        Waves.tick(c, {}, {})
        assert(c.waveState[1].silenced, "silenced")
        assert(Combat.allWavesArrived(c, c.objective), "a silenced wave owes nothing")
    end },

    { name = "every floor's pool deals at least two objective shapes", fn = function()
        -- The share rule the pass was approved with ("About a third, two shapes per floor"): a trip down
        -- one floor meets more than one kind of work. A shape is what the player is asked to DO, so a
        -- break is not an assassination and an escape layered on a kill-all is its own shape.
        local function shapeOf(def)
            local o = def.objective
            if not o then return def.allies and "protect" or nil end
            if o.escape then return "escape" end
            if o.captive then return "rescue" end
            if o.orKillAll then return "either" end
            if o.type == "assassinate" then return o.targets and "break" or "assassinate" end
            if o.type == "killAll" then return (o.protect and "protect") or nil end
            return o.type
        end
        local GROUNDS = { "forest", "cave", "swamp", "volcanic", "tundra", "desert", "spire" }
        local short = {}
        for _, g in ipairs(GROUNDS) do
            for rung = 1, 2 do
                local shapes, n = {}, 0
                for _, def in pairs(Encounter.defs) do
                    if (def.kind == "combat" or def.kind == "elite") and not def.party and def.condition then
                        local ok, yes = pcall(def.condition, { biome = g, depth = 5, rung = rung })
                        local onRung = def.rung == nil or def.rung == rung
                        local sh = ok and yes and onRung and shapeOf(def)
                        if sh and not shapes[sh] then shapes[sh], n = true, n + 1 end
                    end
                end
                if n < 2 then short[#short + 1] = g .. " floor " .. rung .. " (" .. n .. ")" end
            end
        end
        assert(#short == 0, "a floor deals fewer than two objective shapes: " .. table.concat(short, ", "))
    end },

    { name = "every authored objective fight finishes when a real company plays it", fn = function()
        local ids = objectiveFights()
        assert(#ids >= 60, "the pass authored objective fights (found " .. #ids .. ")")
        local undecided, long = {}, {}
        for _, id in ipairs(ids) do
            local r = Run.fight(id)
            print(string.format("    %-48s %-5s %3d turns  esc=%s freed=%s looted=%d", id, tostring(r.result), r.turns, tostring(r.escaped), tostring(r.freed), r.looted))
            if r.result == nil then
                undecided[#undecided + 1] = id
            elseif r.turns > OBJECTIVE_TURN_BUDGET then
                long[#long + 1] = string.format("%s (%d)", id, r.turns)
            end
        end
        assert(#undecided == 0, "never decided: " .. table.concat(undecided, ", "))
        assert(#long == 0, "past the objective budget of " .. OBJECTIVE_TURN_BUDGET .. ": "
            .. table.concat(long, ", "))
    end },
}
