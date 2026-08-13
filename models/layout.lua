-- HOW A GROUND IS CARVED. A biome names a layout (data/biomes/<id>.lua's `layout`) and the layout owns
-- the first pass of generation: which tiles are walkable at all. Everything after the carve -- rivers,
-- the objective and its gates, caches, encounters, guards, the prune, the tier arc -- is shared, because
-- every one of those passes works on an arbitrary walkable graph via BFS over Overworld:pathNeighbors.
--
--   SWAP THE CARVE, KEEP THE PIPELINE.
--
-- That containment is the whole reason seven grounds is a tractable amount of work rather than seven
-- generators. Only three passes ever knew they were standing on a lattice (braid, the river band, and
-- isNode itself), and a layout that has no lattice simply does not use them.
--
-- A layout module is:
--
--   name       for reports
--   carve(grid)      write the walkable tiles. The only required entry.
--   density(grid)    walkable share of the rectangle, for sizing only (Overworld's deriveDims). A
--                    lattice answers 1/spacing, which is what the sizing rule used before layouts
--                    existed, so those boards keep their footprint exactly.
--   ownsWater        true if the carve lays its own channels, which scopes the shared river pass off
--                    it (see Overworld.generate and docs/overworld.md's C2).
--
-- The carve reaches the board through a small API on the grid -- carveCorridor, carveBlob, isNode,
-- cellKey, rng -- rather than through its internals, so a layout stays a description of a SHAPE.

local Registry = require("models.registry")

local Layout = {}

Layout.defs = Registry.load("models/layouts", "models.layouts")

-- The maze is the fallback for anything unnamed or unknown, so a half-written biome blueprint produces
-- the board the game has always had rather than an empty rectangle.
function Layout.get(id)
    return (id and Layout.defs[id]) or Layout.defs.maze
end

return Layout
