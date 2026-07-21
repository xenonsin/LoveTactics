-- The tile-based win types (`reach`, `hold`) and the tick-counted time-based ones (`survive`,
-- `hold`), whose `duration` is a count of ticks -- the unit the clock keeps and the HUD quotes.
-- (`defend` is wave-based, not timed: it wins by clearing every wave -- see tests/flight_leg_spec.lua.)
-- See Combat.evaluate and Arena.resolveRegion.

local Arena = require("models.arena")
local Combat = require("models.combat")

-- A bare combat-like table is enough for Combat.evaluate: it reads units, objective, clock and
-- heldTicks and nothing else. Building a real Combat here would drag in a board, an AI and a
-- timeline to test four branches of one function.
local function fakeCombat(units, objective)
    return { units = units, objective = objective, clock = 0, heldTicks = 0 }
end

local function unit(side, x, y, alive)
    return { side = side, x = x, y = y, alive = alive ~= false, char = { stats = { health = { current = 10 } } } }
end

-- The same, carrying a blueprint id -- what `who`, `protect` and `assassinate` all match on.
local function named(side, x, y, id)
    local u = unit(side, x, y)
    u.char.id = id
    return u
end

-- A flat layout with no obstacles and the party seated on the bottom rows, which is what
-- Arena.generateLayout produces.
local function flatLayout(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = "ground" end
    end
    return {
        cols = cols, rows = rows, tiles = tiles,
        partySpawns = { { x = 1, y = rows }, { x = 2, y = rows } },
        enemySpawns = { { x = 1, y = 1 } },
    }
end

return {
    {
        name = "the far region is the edge the party did not land on",
        fn = function()
            local tiles = Arena.resolveRegion("far", flatLayout(8, 8))
            assert(#tiles == 8, "a clear far edge should offer every column, got " .. #tiles)
            for _, t in ipairs(tiles) do
                assert(t.y == 1, "party spawned at the bottom, so the far edge is row 1")
            end
        end,
    },
    {
        name = "the far region flips when the party spawns at the top instead",
        fn = function()
            local layout = flatLayout(8, 8)
            layout.partySpawns = { { x = 1, y = 1 }, { x = 2, y = 1 } }
            local tiles = Arena.resolveRegion("far", layout)
            assert(tiles[1].y == 8, "party at the top makes row 8 the far edge, got " .. tiles[1].y)
        end,
    },
    {
        name = "the rally region sits just ahead of the party's line, not mid-board",
        fn = function()
            -- Party on the bottom rows (rows 8): rally steps two rows toward the centre -> row 6, close
            -- enough for the party to interpose (unlike `center`, which the enemy reaches first).
            local tiles = Arena.resolveRegion("rally", flatLayout(8, 8))
            assert(#tiles == 8, "a clear rally row should offer every column, got " .. #tiles)
            for _, t in ipairs(tiles) do
                assert(t.y == 6, "party at the bottom (row 8) makes row 6 the rally line, got " .. t.y)
            end
        end,
    },
    {
        name = "the rally region flips inward when the party spawns at the top instead",
        fn = function()
            local layout = flatLayout(8, 8)
            layout.partySpawns = { { x = 1, y = 1 }, { x = 2, y = 1 } }
            local tiles = Arena.resolveRegion("rally", layout)
            assert(tiles[1].y == 3, "party at the top (row 1) steps rally inward to row 3, got " .. tiles[1].y)
        end,
    },
    {
        name = "an unwalkable region still resolves rather than becoming unwinnable",
        fn = function()
            local layout = flatLayout(8, 8)
            -- Bury the whole centre under obstacles: a generated board is allowed to be unlucky.
            for y = 4, 5 do
                for x = 4, 5 do layout.tiles[y][x] = "obstacle" end
            end
            local tiles = Arena.resolveRegion("center", layout)
            assert(#tiles > 0, "a buried region must fall back to some walkable tile, not empty")
            for _, t in ipairs(tiles) do
                assert(layout.tiles[t.y][t.x] ~= "obstacle", "never hand back a tile nobody can stand on")
            end
        end,
    },
    {
        name = "resolving an objective copies it rather than writing tiles into the blueprint",
        fn = function()
            -- The shape a quest blueprint hands over -- immutable, and reused next run.
            local blueprint = { type = "reach", region = "far" }
            local arena = Arena.build({}, {
                party = { "character_knight" },
                composition = function() return { "character_bandit" } end,
                objective = blueprint, seed = 7,
            })
            assert(#arena.objective.tiles > 0, "the built arena should carry resolved tiles")
            assert(blueprint.tiles == nil, "the blueprint must not have been mutated")
        end,
    },
    {
        name = "reach is won by any one body on the ground, not the whole party",
        fn = function()
            local goal = { { x = 3, y = 1 } }
            local combat = fakeCombat({ unit("party", 3, 8), unit("party", 4, 8) },
                { type = "reach", tiles = goal })
            assert(Combat.evaluate(combat) == nil, "nobody across yet")

            combat.units[1].x, combat.units[1].y = 3, 1
            assert(Combat.evaluate(combat) == "win", "one body across ends it; stragglers do not matter")
        end,
    },
    {
        name = "an enemy standing on the ground contests it and stops the hold count",
        fn = function()
            local ground = { { x = 4, y = 4 } }
            local combat = fakeCombat({ unit("party", 4, 4), unit("enemy", 9, 9) }, { type = "hold", tiles = ground })
            assert(Combat.holdsGround(combat, ground), "party alone on the tile holds it")

            combat.units[2].x, combat.units[2].y = 4, 4 -- an enemy boot on the same ground
            assert(not Combat.holdsGround(combat, ground), "a contested tile is not held")

            combat.units[2].alive = false
            assert(Combat.holdsGround(combat, ground), "a corpse contests nothing")
        end,
    },
    {
        name = "hold banks only the ticks the ground was actually held",
        fn = function()
            local ground = { { x = 4, y = 4 } }
            local combat = fakeCombat({ unit("party", 1, 1), unit("enemy", 9, 9) }, { type = "hold", tiles = ground, duration = 10 })

            Combat.accrueHold(combat, 5) -- nobody on it: banks nothing
            assert(combat.heldTicks == 0, "time off the ground must not count, got " .. combat.heldTicks)

            combat.units[1].x, combat.units[1].y = 4, 4
            Combat.accrueHold(combat, 5)
            assert(combat.heldTicks == 5, "time on the ground counts, got " .. combat.heldTicks)
            assert(Combat.evaluate(combat) == nil, "the duration is 10 ticks; 5 is not there yet")

            Combat.accrueHold(combat, 5)
            assert(Combat.evaluate(combat) == "win", "10 banked ticks is the duration asked for")
        end,
    },
    {
        name = "a timed objective counts its duration in ticks, the clock's own unit",
        fn = function()
            -- `duration` is quoted in the same unit `combat.clock` accumulates (elapsed initiative),
            -- so a designer's number means the ticks it says and the HUD countdown reads the same.
            local combat = fakeCombat({ unit("party", 1, 1) }, { type = "survive", duration = 15 })
            combat.clock = 14
            assert(Combat.evaluate(combat) == nil, "one tick short of the duration is not done")

            combat.clock = 15
            assert(Combat.evaluate(combat) == "win", "the clock reaching the tick duration ends it")
        end,
    },
    {
        name = "a party wipe still loses a tile objective it was about to win",
        fn = function()
            local goal = { { x = 3, y = 1 } }
            local combat = fakeCombat({ unit("party", 3, 1, false) }, { type = "reach", tiles = goal })
            assert(Combat.evaluate(combat) == "loss", "the wipe check comes first, whatever the objective")
        end,
    },
    {
        -- An escort is a reach whose ARRIVAL matters, not whose breakthrough does. Without `who`,
        -- the player wins by sprinting a scout across and leaving the wagons standing in the road.
        name = "an escorted reach is won only by the body the objective names",
        fn = function()
            local goal = { { x = 3, y = 1 } }
            local scout = named("party", 3, 8, "character_knight")
            local driver = named("party", 4, 8, "character_caravan_driver")
            local combat = fakeCombat({ scout, driver },
                { type = "reach", tiles = goal, who = "character_caravan_driver" })

            scout.x, scout.y = 3, 1
            assert(Combat.evaluate(combat) == nil, "the escort is not finished by whoever got there first")

            driver.x, driver.y = 3, 1
            assert(Combat.evaluate(combat) == "win", "the named charge across the line ends it")
        end,
    },
    {
        name = "a summoned duplicate cannot finish an escort for the charge it copies",
        fn = function()
            local goal = { { x = 3, y = 1 } }
            local fake = named("party", 3, 1, "character_caravan_driver")
            fake.summoned = true
            local combat = fakeCombat({ fake, named("party", 4, 8, "character_caravan_driver") },
                { type = "reach", tiles = goal, who = "character_caravan_driver" })
            assert(Combat.evaluate(combat) == nil,
                "a summon sharing the charge's id must not deliver the column for it")
        end,
    },
    {
        -- The positional handle an escortee walks on. `objectiveUnit` cannot serve here: a column is
        -- not closing on a body, it is closing on the exit.
        name = "an escort reads the objective's ground, and falls back when there is none",
        fn = function()
            local AI = require("models.ai")
            -- Seated hard left so the two candidate tiles are not equidistant (a tie would make the
            -- assertion depend on list order rather than on distance).
            local walker = named("party", 2, 8, "character_caravan_driver")

            local combat = fakeCombat({ walker }, { type = "reach", tiles = { { x = 9, y = 1 }, { x = 1, y = 1 } } })
            local tile = AI.objectiveTile(combat, walker)
            assert(tile and tile.x == 1 and tile.y == 1, "it walks at the NEAREST tile of the ground")

            assert(AI.objectiveTile(fakeCombat({ walker }, { type = "killAll" }), walker) == nil,
                "an objective naming no ground gives no tile, so `advance` falls back to approach")
            assert(AI.POSTURES.escort and AI.POSTURES.escort.move == "advance",
                "the escort posture walks for the exit")
        end,
    },

    -- -----------------------------------------------------------------------
    -- Point of view
    --
    -- Combat.evaluate answers for the side the local player is running. It used to be able to speak
    -- only for the party, which is fine while the party is always ours and never enough for a duel,
    -- where the same board has to read as a win to one player and a loss to the other.
    -- -----------------------------------------------------------------------
    {
        name = "a wipe is a loss for whoever was wiped, and killAll reads from either chair",
        fn = function()
            local partyDown = fakeCombat({ unit("party", 1, 8, false), unit("enemy", 1, 1) },
                { type = "killAll" })
            assert(Combat.outcomeFor(partyDown, "party") == "loss", "the wiped party lost")
            assert(Combat.outcomeFor(partyDown, "enemy") == "win", "the side still standing won")

            local enemyDown = fakeCombat({ unit("party", 1, 8), unit("enemy", 1, 1, false) },
                { type = "killAll" })
            assert(Combat.outcomeFor(enemyDown, "party") == "win", "the party cleared the board")
            assert(Combat.outcomeFor(enemyDown, "enemy") == "loss", "the cleared side lost")

            local ongoing = fakeCombat({ unit("party", 1, 8), unit("enemy", 1, 1) }, { type = "killAll" })
            assert(Combat.outcomeFor(ongoing, "party") == nil, "a live fight is undecided")
            assert(Combat.outcomeFor(ongoing, "enemy") == nil, "undecided from both chairs")
        end,
    },
    {
        name = "evaluate speaks for combat.playerSide, and still defaults to the party",
        fn = function()
            local c = fakeCombat({ unit("party", 1, 8), unit("enemy", 1, 1, false) }, { type = "killAll" })
            assert(Combat.evaluate(c) == "win", "with no side named it answers for the party")

            c.playerSide = "enemy"
            assert(Combat.evaluate(c) == "loss", "holding the enemy side, that board is a defeat")

            c.playerSide = "party"
            assert(Combat.evaluate(c) == "win", "and back again")
        end,
    },
    {
        -- An authored objective belongs to the party; the other side's job is only to stop it. So
        -- its standing is the party's, mirrored -- not its own separate pursuit of the same goal.
        name = "an authored objective reads to the other side as the mirror of the party's",
        fn = function()
            local walker = named("party", 1, 1, "character_knight")
            local won = fakeCombat({ walker, unit("enemy", 5, 5) },
                { type = "reach", tiles = { { x = 1, y = 1 } } })
            assert(Combat.outcomeFor(won, "party") == "win", "the party reached the ground")
            assert(Combat.outcomeFor(won, "enemy") == "loss", "so the side meant to stop it failed")

            local open = fakeCombat({ named("party", 4, 4, "character_knight"), unit("enemy", 5, 5) },
                { type = "reach", tiles = { { x = 1, y = 1 } } })
            assert(Combat.outcomeFor(open, "party") == nil, "still walking")
            assert(Combat.outcomeFor(open, "enemy") == nil, "still stopping them")
        end,
    },
}
