-- Tests for the `control` objective in models/combat.lua: the multiplayer/draft ruleset where both
-- sides bank points for holding a MOVING score node, and the higher score at a tick limit wins.
--
-- These drive the objective's pure helpers over hand-built combat tables rather than simulating a
-- whole battle: the helpers only read combat.objective / combat.clock / combat.units / combat.score,
-- and the point of the ruleset is that everything the node's position and the outcome depend on is a
-- pure function of those -- no love.*, no wall-clock, no RNG -- so a lockstep duel can't desync on it.
-- The real-time chess clock is deliberately NOT here: it lives in states/battle.lua, not the model.
--
-- Pure logic, runs headless.

local Combat = require("models.combat")

local function unit(side, x, y)
    return { alive = true, side = side, x = x, y = y }
end

-- A combat table carrying just what the control helpers touch.
local function combatWith(objective, units)
    return { objective = objective, clock = 0, units = units or {}, score = { party = 0, enemy = 0 } }
end

-- A two-waypoint node: tiles (1,1) then (5,5), moving every 10 ticks.
local function movingObjective(maxTicks)
    return {
        type = "control",
        maxTicks = maxTicks or 100,
        moveEvery = 10,
        nodes = {
            { { x = 1, y = 1 } },
            { { x = 5, y = 5 } },
        },
    }
end

return {
    {
        name = "a side that solely stands on the node controls it; a contested node controls for no one",
        fn = function()
            local obj = { type = "control", nodes = { { { x = 1, y = 1 } } } }

            local sole = combatWith(obj, { unit("party", 1, 1), unit("enemy", 3, 3) })
            assert(Combat.controlledBy(sole, Combat.controlTiles(sole)) == "party",
                "the party alone on the node controls it")

            local contested = combatWith(obj, { unit("party", 1, 1), unit("enemy", 1, 1) })
            assert(Combat.controlledBy(contested, Combat.controlTiles(contested)) == nil,
                "an enemy boot on the same tile contests it, so no one controls it")

            local empty = combatWith(obj, { unit("party", 3, 3), unit("enemy", 4, 4) })
            assert(Combat.controlledBy(empty, Combat.controlTiles(empty)) == nil,
                "an unoccupied node controls for no one")
        end,
    },
    {
        name = "accrueControl banks a point per tick to the sole holder, and nothing while contested",
        fn = function()
            local obj = { type = "control", nodes = { { { x = 1, y = 1 } } } }
            local combat = combatWith(obj, { unit("party", 1, 1), unit("enemy", 3, 3) })

            Combat.accrueControl(combat, 5)
            assert(Combat.scoreFor(combat, "party") == 5, "party held 5 ticks")
            assert(Combat.scoreFor(combat, "enemy") == 0, "enemy held none")

            -- Enemy walks onto the node: now contested, the count stops for everyone.
            combat.units[2].x, combat.units[2].y = 1, 1
            Combat.accrueControl(combat, 5)
            assert(Combat.scoreFor(combat, "party") == 5, "a contested node banks nothing")
        end,
    },
    {
        name = "the node relocates on the deterministic schedule from the clock alone",
        fn = function()
            local combat = combatWith(movingObjective(), {})

            combat.clock = 0
            assert(Combat.controlNodeIndex(combat) == 1, "first waypoint at t=0")
            assert(Combat.controlTiles(combat)[1].x == 1, "waypoint 1 is (1,1)")

            combat.clock = 10
            assert(Combat.controlNodeIndex(combat) == 2, "second waypoint at t=10")
            assert(Combat.controlTiles(combat)[1].x == 5, "waypoint 2 is (5,5)")

            combat.clock = 20
            assert(Combat.controlNodeIndex(combat) == 1, "it cycles back to waypoint 1 at t=20")

            -- Determinism: the same clock always yields the same node, no stored state to drift.
            combat.clock = 15
            local a = Combat.controlNodeIndex(combat)
            combat.clock = 15
            assert(Combat.controlNodeIndex(combat) == a, "same clock, same node")
        end,
    },
    {
        name = "at the tick limit the higher score wins, and evaluate reads it opposite for the two sides",
        fn = function()
            local combat = combatWith(movingObjective(100), { unit("party", 9, 9), unit("enemy", 8, 8) })
            combat.score = { party = 40, enemy = 25 }

            -- Before the limit: no result yet.
            combat.clock = 50
            assert(Combat.outcomeFor(combat, "party") == nil, "the fight is still on before the limit")

            -- At the limit: the higher score decides, symmetrically.
            combat.clock = 100
            assert(Combat.outcomeFor(combat, "party") == "win", "party had the higher score")
            assert(Combat.outcomeFor(combat, "enemy") == "loss", "so the enemy lost the same board")

            combat.playerSide = "enemy"
            assert(Combat.evaluate(combat) == "loss", "evaluate speaks from the local player's side")
        end,
    },
    {
        name = "a wipe ends a control fight immediately -- last side standing wins",
        fn = function()
            local combat = combatWith(movingObjective(100), { unit("party", 1, 1) })
            combat.units[2] = { alive = false, side = "enemy", x = 2, y = 2 }
            combat.clock = 5 -- nowhere near the tick limit
            assert(Combat.outcomeFor(combat, "party") == "win", "the last side standing takes it")
            assert(Combat.outcomeFor(combat, "enemy") == "loss", "the wiped side loses")
        end,
    },
    {
        name = "the tie-break settles a level score by units standing, then last holder, then a draw",
        fn = function()
            -- Equal score, party has more units standing -> party.
            local combat = combatWith(movingObjective(100),
                { unit("party", 1, 1), unit("party", 2, 2), unit("enemy", 8, 8) })
            combat.score = { party = 30, enemy = 30 }
            assert(Combat.controlWinner(combat) == "party", "more units standing breaks a tied score")

            -- Equal score AND equal units -> whoever held the node last.
            local even = combatWith(movingObjective(100), { unit("party", 1, 1), unit("enemy", 8, 8) })
            even.score = { party = 30, enemy = 30 }
            even.lastHolder = "enemy"
            assert(Combat.controlWinner(even) == "enemy", "last holder breaks an otherwise-even score")

            -- Nothing to separate them at all -> a genuine draw, and both read the limit as a loss.
            local draw = combatWith(movingObjective(100), { unit("party", 1, 1), unit("enemy", 8, 8) })
            draw.score = { party = 0, enemy = 0 }
            assert(Combat.controlWinner(draw) == nil, "a true draw has no winner")
            draw.clock = 100
            assert(Combat.outcomeFor(draw, "party") == "loss"
                and Combat.outcomeFor(draw, "enemy") == "loss", "a draw is a loss for both")
        end,
    },
}
