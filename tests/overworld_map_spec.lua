-- Tests for ui/overworld_map.lua's mouse click-to-path (OverworldMap:pathTo):
-- it must route the player only across *revealed* (seen) tiles it can actually
-- walk (gates need their key), and never through fog or a locked gate.
--
-- pathTo depends only on self.grid / self.px / self.py / self.keysHeld, so we drive
-- it against a bare table wired to the OverworldMap metatable -- no window, font,
-- or love.graphics needed (the module itself is require-safe headless).

local OverworldMap = require("ui.overworld_map")
local Overworld = require("models.overworld")
local Tileset = require("models.tileset")
local InputMode = require("input_mode")

local function typeWalkable(tile)
    local def = Tileset.get().tiles[tile]
    return def ~= nil and def.walkable == true
end

-- A pathTo-capable stand-in positioned at the grid's start with the given keys.
-- A minimal stand-in for OverworldMap.new: enough state to drive movement, without the fonts and
-- layout the real constructor builds. It has to carry every field :step writes THROUGH, though --
-- `cacheHaul` is one, and it was missing here until a generation change moved a cache onto the tile
-- beside the start on this seed and :step tried to bank into nil. A fixture that lists a subset of the
-- constructor's fields is only ever as correct as the board it happens to be handed.
local function walker(grid, keysHeld)
    return setmetatable({
        grid = grid,
        px = grid.start.x, py = grid.start.y,
        keysHeld = keysHeld or {},
        cacheHaul = {},
    }, { __index = OverworldMap })
end

-- Reveal every cell so fog never blocks the route under test.
local function revealAll(grid)
    for y = 1, grid.rows do
        for x = 1, grid.cols do grid:get(x, y).seen = true end
    end
end

-- Follow a { dx, dy } step list from the start; assert every tile is walkable with
-- the held keys, and return where it lands.
local function walk(grid, keysHeld, steps)
    local x, y = grid.start.x, grid.start.y
    for _, s in ipairs(steps) do
        x, y = x + s[1], y + s[2]
        assert(grid:isWalkable(x, y, keysHeld), "step routed onto a blocked tile at " .. x .. "," .. y)
    end
    return x, y
end

-- A revealed, walkable cell well outside the walker's vision disc -- the "mapped but dark" ground the
-- fog rule is about. Asked of the grid rather than hardcoded, because which tiles are trail moves with
-- every generation change.
local function farCell(grid, w)
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid:get(x, y)
            if c.seen and typeWalkable(c.tile)
                and not grid:inVision(w.px, w.py, x, y, w.visionRadius) then
                return c
            end
        end
    end
    error("no revealed tile outside vision on this board")
end

local function genOpen(seed)
    return Overworld.generate({
        seed = seed, biome = "forest", encounterCount = 4, keyCount = 0,
        encounters = { { kind = "combat", weight = 1 } },
        objective = { name = "Boss" },
    })
end

return {
    {
        name = "pathTo reaches the objective across revealed trail",
        fn = function()
            local grid = genOpen(3)
            revealAll(grid)
            local w = walker(grid)
            local path = w:pathTo(grid.objective.x, grid.objective.y)
            assert(path and #path > 0, "expected a non-empty path to the objective")
            local ex, ey = walk(grid, {}, path)
            assert(ex == grid.objective.x and ey == grid.objective.y,
                "path ended at " .. ex .. "," .. ey .. " not the objective")
        end,
    },
    {
        name = "pathTo refuses an unrevealed target (no routing through fog)",
        fn = function()
            local grid = genOpen(4)
            revealAll(grid)
            grid:get(grid.objective.x, grid.objective.y).seen = false
            local w = walker(grid)
            assert(w:pathTo(grid.objective.x, grid.objective.y) == nil,
                "should not path onto an unseen tile")
        end,
    },
    {
        name = "pathTo won't cross a locked gate without the key, but will with it",
        fn = function()
            -- Find a seed whose objective sits behind at least one gate.
            local grid
            for seed = 1, 40 do
                local g = Overworld.generate({
                    seed = seed, biome = "forest", encounterCount = 6, keyCount = 2,
                    encounters = { { kind = "combat", weight = 1 } },
                    objective = { name = "Boss" },
                })
                if #g.keyIds > 0 then grid = g; break end
            end
            assert(grid, "no keyed map generated in 40 seeds")
            revealAll(grid)

            -- Without keys the gate blocks the objective route entirely.
            local locked = walker(grid, {})
            assert(locked:pathTo(grid.objective.x, grid.objective.y) == nil,
                "reached the objective through a locked gate with no key")

            -- Holding every key opens the route.
            local keys = {}
            for _, id in ipairs(grid.keyIds) do keys[id] = true end
            local unlocked = walker(grid, keys)
            local path = unlocked:pathTo(grid.objective.x, grid.objective.y)
            assert(path and #path > 0, "objective unreachable even with all keys")
            local ex, ey = walk(grid, keys, path)
            assert(ex == grid.objective.x and ey == grid.objective.y,
                "keyed path ended at " .. ex .. "," .. ey .. " not the objective")
        end,
    },
    {
        name = "retreatFromEncounter steps the token back onto the tile it arrived from",
        fn = function()
            local grid = genOpen(3)
            revealAll(grid)
            local w = walker(grid)
            -- Find a start-adjacent walkable tile: the tile the token "came from" before landing on
            -- the encounter. Stand the token on the encounter (an adjacent tile) and record the prev.
            local prevX, prevY = grid.start.x, grid.start.y
            local encX, encY
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local nx, ny = prevX + d[1], prevY + d[2]
                if grid:isWalkable(nx, ny, {}) then encX, encY = nx, ny; break end
            end
            assert(encX, "no walkable neighbour of the start to stage the encounter on")
            w.px, w.py = encX, encY
            w.slidePrevX, w.slidePrevY = prevX, prevY
            w.slideT = 0.2
            w:retreatFromEncounter()
            assert(w.px == prevX and w.py == prevY,
                "expected the token back on " .. prevX .. "," .. prevY .. " got " .. w.px .. "," .. w.py)
            assert(w.slidePrevX == nil and w.slideT == 0, "the slide animation was cancelled")
            assert(w.heldDir == nil and w.autoPath == nil, "any in-flight walk was cancelled")
        end,
    },
    {
        name = "retreatFromEncounter leaves the token put when there is no recorded previous tile",
        fn = function()
            local grid = genOpen(3)
            revealAll(grid)
            local w = walker(grid)
            w.px, w.py = grid.start.x, grid.start.y
            w.slidePrevX, w.slidePrevY = nil, nil
            w:retreatFromEncounter()
            assert(w.px == grid.start.x and w.py == grid.start.y,
                "with no previous tile the token stays where it stands")
        end,
    },
    {
        name = "stepping into an un-engaged stop fires onApproach first, from the tile BEFORE it",
        fn = function()
            local grid = genOpen(3)
            revealAll(grid)
            local w = walker(grid)
            w.visionRadius = 1
            local sx, sy = grid.start.x, grid.start.y
            local dx, dy
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                if grid:isWalkable(sx + d[1], sy + d[2], {}) then dx, dy = d[1], d[2]; break end
            end
            assert(dx, "no walkable neighbour of the start to stage a stop on")
            local dest = grid:get(sx + dx, sy + dy)
            dest.encounter, dest.cleared = { kind = "combat", name = "Ambush" }, nil

            -- The whole point of the hook: states/game.lua autosaves here, and the run it writes must
            -- describe the player standing SHORT of the fight, with the step's own effects still ahead.
            local log = {}
            w.onApproach = function(cell)
                log[#log + 1] = "approach"
                assert(cell == dest, "onApproach names the stop being walked into")
                assert(w.px == sx and w.py == sy, "onApproach fired after the token had already moved")
            end
            w.onArrive = function() log[#log + 1] = "arrive" end
            w.onEncounter = function() log[#log + 1] = "encounter" end

            w:step(dx, dy)
            assert(table.concat(log, ",") == "approach,arrive,encounter",
                "expected approach before the landing hooks, got: " .. table.concat(log, ","))
            assert(w.px == dest.x and w.py == dest.y, "the step still lands on the stop")
        end,
    },
    {
        name = "onApproach stays quiet for a plain tile and for a stop already cleared",
        fn = function()
            local grid = genOpen(3)
            revealAll(grid)
            local sx, sy = grid.start.x, grid.start.y
            local dx, dy
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                if grid:isWalkable(sx + d[1], sy + d[2], {}) then dx, dy = d[1], d[2]; break end
            end
            local dest = grid:get(sx + dx, sy + dy)

            local approaches = 0
            local function run(setup)
                local w = walker(grid)
                w.visionRadius = 1
                w.onApproach = function() approaches = approaches + 1 end
                setup()
                w:step(dx, dy)
            end

            dest.encounter = nil
            run(function() end)
            assert(approaches == 0, "an empty tile is not an approach -- nothing to save for")

            dest.encounter, dest.cleared = { kind = "treasure" }, true
            run(function() end)
            assert(approaches == 0, "a stop already resolved is not an approach")
        end,
    },
    {
        name = "a mapped tile outside the vision disc is not lit (markers hang off :lit)",
        fn = function()
            local grid = genOpen(3)
            revealAll(grid)
            local w = walker(grid)
            w.visionRadius = 2

            assert(w:lit(grid.start.x, grid.start.y), "the tile under the token is lit")
            local far = farCell(grid, w)
            assert(w:lit(far.x, far.y) == nil,
                "a tile mapped an hour ago is remembered ground, not something you can see")

            -- Unmapped ground is not lit either, even standing on top of it: the two tests are AND-ed,
            -- so nothing can slip through by being near without having been discovered.
            local here = grid:get(grid.start.x, grid.start.y)
            here.seen = false
            assert(w:lit(grid.start.x, grid.start.y) == nil, "an undiscovered tile is never lit")
            here.seen = true
        end,
    },
    {
        name = "the hovered-fight readout goes dark with the marker it names",
        fn = function()
            local grid = genOpen(3)
            revealAll(grid)
            local w = walker(grid)
            w.visionRadius = 2
            local far = farCell(grid, w)
            far.encounter, far.cleared = { kind = "combat", name = "Ambush" }, nil

            local restore = InputMode.current
            InputMode.set("mouse")
            w.hoverX, w.hoverY = far.x, far.y
            assert(w:hoveredFight() == nil,
                "naming a fight the fog is holding back turns the pointer into a probe")

            -- Stand on it and the same pointer names it again -- the readout follows the light, not the
            -- mouse, which is why the hover is stored as a TILE rather than as the cell it resolved to.
            w.px, w.py = far.x, far.y
            assert(w:hoveredFight() == far, "a lit fight still reads under the pointer")
            InputMode.set(restore)
        end,
    },
    {
        name = "pathTo returns nil for the player's own tile and for walls",
        fn = function()
            local grid = genOpen(5)
            revealAll(grid)
            local w = walker(grid)
            assert(w:pathTo(grid.start.x, grid.start.y) == nil, "no path to the current tile")
            -- Find a revealed non-walkable (forest/rock/water) tile: unreachable.
            for y = 1, grid.rows do
                for x = 1, grid.cols do
                    if not typeWalkable(grid:get(x, y).tile) then
                        assert(w:pathTo(x, y) == nil, "pathed onto a non-walkable tile")
                        return
                    end
                end
            end
        end,
    },
}
