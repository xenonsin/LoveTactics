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

local function typeWalkable(tile)
    local def = Tileset.get().tiles[tile]
    return def ~= nil and def.walkable == true
end

-- A pathTo-capable stand-in positioned at the grid's start with the given keys.
local function walker(grid, keysHeld)
    return setmetatable({
        grid = grid,
        px = grid.start.x, py = grid.start.y,
        keysHeld = keysHeld or {},
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
