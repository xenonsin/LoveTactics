-- Tests for Combat.planMoveVia (models/combat.lua): validation of an EXPLICIT, player-steered walk
-- route -- the model behind the battle state's steerable path preview. Unlike planMove (which derives
-- the shortest path), planMoveVia is handed a route and must accept only a legal one: origin-first,
-- one cardinal step at a time, no double-back, across walkable/unoccupied/wall-free tiles, with the
-- summed terrain cost inside the movement budget. A deliberate detour is allowed and costs what it
-- would if walked. Pure logic, runs headless.

local Character = require("models.character")
local Combat = require("models.combat")

-- A flat, all-walkable arena of the given size (no terrain).
local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

-- A { char, x, y } spawn entry, stripped of its innate trait + bound signature relic (whose
-- combat-start summon would drop an extra unit on the board and skew the occupancy checks here),
-- mirroring tests/combat_spec.lua's fixture.
local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0, startX = u.x, startY = u.y }
end

-- Give a unit a clean, known movement budget (no armor penalty / status modifier in the way).
local function setBudget(u, n)
    u.char.stats.movement = n
    u.bonus = {}
end

-- Build a { x, y } route from a list of {x, y} pairs.
local function route(...)
    local cells = {}
    for _, p in ipairs({ ... }) do cells[#cells + 1] = { x = p[1], y = p[2] } end
    return cells
end

return {
    {
        name = "planMoveVia accepts a straight contiguous route and sums its terrain cost",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_knight", 2, 2) }, {})
            local u = c.units[1]
            setBudget(u, 6)
            openTurn(c, u)

            local plan = Combat.planMoveVia(c, u, route({ 2, 2 }, { 3, 2 }, { 4, 2 }))
            assert(plan, "a legal straight route is accepted")
            assert(plan.cost == 2, "two ground steps cost 2, got " .. tostring(plan.cost))
            assert(#plan.path == 3, "the plan keeps the origin plus one tile per step")
            assert(plan.path[1].x == 2 and plan.path[1].y == 2, "path[1] is the origin")
            assert(plan.path[3].x == 4 and plan.path[3].y == 2, "the last tile is the destination")
        end,
    },
    {
        name = "a steered detour is allowed within budget and costs more than the shortest path",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_knight", 2, 2) }, {})
            local u = c.units[1]
            setBudget(u, 6)
            openTurn(c, u)

            -- (2,2) -> (4,2): shortest is the 2-tile straight line (cost 2). A wander down and back up
            -- is 4 tiles (cost 4), still <= the budget of 6.
            local short = Combat.planMove(c, u, 4, 2)
            assert(short and short.cost == 2, "the shortest route to (4,2) costs 2")

            local detour = Combat.planMoveVia(c, u,
                route({ 2, 2 }, { 2, 3 }, { 3, 3 }, { 4, 3 }, { 4, 2 }))
            assert(detour, "the detour is a legal walk within budget")
            assert(detour.cost == 4, "the 4-tile detour costs 4, got " .. tostring(detour.cost))
            assert(detour.cost > short.cost, "a deliberate detour costs more than the direct route")
        end,
    },
    {
        name = "planMoveVia rejects a route that breaks contiguity, doubles back, or leaves the origin",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_knight", 2, 2) }, {})
            local u = c.units[1]
            setBudget(u, 6)
            openTurn(c, u)

            local _, whyGap = Combat.planMoveVia(c, u, route({ 2, 2 }, { 4, 2 }))
            assert(whyGap == "not contiguous", "a non-adjacent hop is rejected, got " .. tostring(whyGap))

            local _, whyBack = Combat.planMoveVia(c, u, route({ 2, 2 }, { 3, 2 }, { 2, 2 }))
            assert(whyBack == "revisit", "stepping back onto a visited tile is rejected, got " .. tostring(whyBack))

            local _, whyOrigin = Combat.planMoveVia(c, u, route({ 3, 2 }, { 4, 2 }))
            assert(whyOrigin == "not from origin", "a route not starting on the unit is rejected")
        end,
    },
    {
        name = "planMoveVia rejects a route crossing an occupied, blocked, or over-budget tile",
        fn = function()
            -- An ally sits at (3,2), blocking a straight walk east.
            local c = Combat.new(arena(6, 6),
                { unit("character_knight", 2, 2), unit("character_archer", 3, 2) }, {})
            local u = c.units[1]
            setBudget(u, 6)
            openTurn(c, u)

            local _, whyOcc = Combat.planMoveVia(c, u, route({ 2, 2 }, { 3, 2 }))
            assert(whyOcc == "occupied", "a route through a unit is rejected, got " .. tostring(whyOcc))

            -- A non-walkable tile at (2,3) can't be crossed.
            c.arena.tiles[3][2].walkable = false
            local _, whyBlocked = Combat.planMoveVia(c, u, route({ 2, 2 }, { 2, 3 }))
            assert(whyBlocked == "blocked", "a route through a wall tile is rejected, got " .. tostring(whyBlocked))

            -- Budget 2: a 4-tile detour overshoots it (routed north, clear of the occupied (3,2)
            -- and the blocked (2,3) tiles above).
            setBudget(u, 2)
            local _, whyFar = Combat.planMoveVia(c, u,
                route({ 2, 2 }, { 2, 1 }, { 3, 1 }, { 4, 1 }, { 4, 2 }))
            assert(whyFar == "too far", "a route past the movement budget is rejected, got " .. tostring(whyFar))
        end,
    },
    {
        name = "a steered plan drives beginMove/stepMove along its exact route to the destination",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_knight", 2, 2) }, {})
            local u = c.units[1]
            setBudget(u, 6)
            openTurn(c, u)

            local plan = Combat.planMoveVia(c, u,
                route({ 2, 2 }, { 2, 3 }, { 3, 3 }, { 4, 3 }, { 4, 2 }))
            assert(plan, "the detour plan is legal")

            local walk = Combat.beginMove(c, plan)
            assert(Combat.hasMoved(c), "opening the walk spends the turn's one move")
            local steppedThroughDetour = false
            for i = 2, #plan.path do
                assert(Combat.stepMove(c, walk), "a step remains")
                if u.x == 2 and u.y == 3 then steppedThroughDetour = true end
                assert(u.x == plan.path[i].x and u.y == plan.path[i].y,
                    "the unit stands on route tile " .. i)
            end
            assert(Combat.stepMove(c, walk) == false, "the walk ends at the destination")
            assert(steppedThroughDetour, "the unit actually walked the detour (through (2,3))")
            assert(u.x == 4 and u.y == 2, "the unit arrives at the steered destination")
        end,
    },
}
