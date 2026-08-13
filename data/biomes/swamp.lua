-- Biome blueprint. Swamp is loose, wet and slow: wide trails through standing water, more rivers than
-- any other biome above ground.
--
-- Its battle floor is `mire` (models/arena.lua) -- ground that charges a mountain's price and gives back
-- none of a mountain's reach. Its rises are forest rather than mountain, so there is no high ground on a
-- swamp board at all: nothing here grants a unit extra range, and the only thing terrain does is take
-- steps away. That makes it the exact inverse of the desert, which is also slow but at least lets
-- everyone see; here the cover is thick and the footing is worse.
--
-- Signature ground: a grasping hollow, which Roots on ENTRY rather than taxing occupancy -- it prices
-- the crossing, not the standing. On the board where crossing is already the expensive part, it is the
-- one hazard that punishes exactly what the biome is about.
return {
    name = "Swamp",
    tileset = "swamp", -- data/tilesets/swamp.lua (art for this biome)
    layout = "drowned", -- the forest carve, a third of it under shallows (models/layouts/drowned.lua)
    spacing = 4, -- loose, like the forest it drowned
    rivers = { min = 2, max = 4 }, -- the wettest surface biome; water is the default, not a feature
    hazard = { id = "hazard_grasping_hollow", min = 1, max = 2 },
}
