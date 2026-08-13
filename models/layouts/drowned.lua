-- DROWNED: the forest's own carve, gone under.
--
-- The swamp is not a different topology, it is a wetter one -- data/biomes/swamp.lua says so in its own
-- words, "loose, like the forest it drowned", and gives it the forest's spacing to prove it. So this is
-- models/layouts/glades.lua exactly: the same backtracker, the same braid rate, the same clearings
-- opened at through-nodes with the same spur protection. What differs is what the trail is MADE of.
--
-- About a third of the walkable ground stands under shallows. Shallows are walkable at double cost and
-- conduct (models/terrain.lua), so a drowned glade is still a perfectly good board -- it is one where
-- every repositioning costs twice and there is no high ground to buy with the spending. That is the
-- blueprint's own claim about this ground, that terrain here only ever takes steps away, and it now
-- happens at both scales: crossing the swamp is slow in the same units that fighting in it is slow.
--
-- The rivers are the pipeline's own (data/biomes/swamp.lua asks for two to four, the most of any surface
-- ground), so this layout does NOT declare ownsWater -- it lays pools, not channels, and the channels
-- and their one-tile bridges are still the shared pass's job.

local Glades = require("models.layouts.glades")

local Drowned = {}

Drowned.name = "Drowned"
Drowned.density = Glades.density

-- How much of the trail stands in water, and how big a pool gets. Pools are laid only on ground the
-- carve already opened -- never into the thicket -- so the topology is the forest's exactly and only the
-- going changes. Flooding the fill would put walkable ground inside the walls and quietly dissolve the
-- maze.
local POOLS_PER_100 = 9
local POOL_MIN, POOL_MAX = 1, 3

function Drowned.carve(grid)
    Glades.carve(grid)

    local pools = math.max(6, math.floor(grid.cols * grid.rows / 100 * POOLS_PER_100))
    for _ = 1, pools do
        local cx = grid.rng:random(1 + grid.margin, grid.cols - grid.margin)
        local cy = grid.rng:random(1 + grid.margin, grid.rows - grid.margin)
        local radius = grid.rng:random(POOL_MIN, POOL_MAX)
        for dy = -radius, radius do
            for dx = -radius, radius do
                if dx * dx + dy * dy <= radius * radius + grid.rng:random() * radius then
                    local c = grid.cells[cy + dy] and grid.cells[cy + dy][cx + dx]
                    -- Only trail floods. A pool that ate the fill would open a hole in a wall.
                    if c and c.tile == "path" then c.tile = "water" end
                end
            end
        end
    end
end

return Drowned
