-- Forest biome tileset (art only). Tile types + walkability are universal and
-- live in models/tileset.lua; here we only name the spritesheet and the pre-art
-- fallback colours (leafy greens, brown trails). `index` may be overridden per
-- type if this sheet's layout differs from the canonical row-major order.
--
-- Until assets/overworld/forest.png exists, the widget draws the `color` rects
-- (see models/sprite.lua's tolerant loader), so the map is playable before art.
--
-- THE WALKABLE HALF HAS TO READ APART FROM THE SOLID HALF, which is a biome's job and not the terrain
-- table's. models/terrain.lua gives `forest` and `thicket` the same green, and that was harmless while
-- one of them only ever appeared on a battle board and the other only on the map. They now stand side
-- by side on both surfaces -- the map is the board (models/arena.lua's Arena.fromGrid), and an authored
-- layout can lay walkable cover into a clearing (data/overworld/tutorial_flight.lua) -- so a player
-- looking at a clump of trees has no way to know whether it is something to hide behind or the wall,
-- and a whole tactical layer goes invisible. The three overrides below are that answer: cover is
-- lighter and scrubbier than the canopy, the high ground is paler than the boulders at its foot, and a
-- ford is shallower and greener than the river it is a crossing of.
return {
    image = "assets/overworld/forest.png",
    tileSize = 16,
    tiles = {
        thicket = { color = { 0.10, 0.24, 0.12 } }, -- dense canopy fill
        forest = { color = { 0.22, 0.42, 0.20 } },  -- walkable scrub: cover you can stand in, and it burns
        grass  = { color = { 0.16, 0.32, 0.16 } },
        rock   = { color = { 0.34, 0.32, 0.30 } },
        mountain = { color = { 0.54, 0.52, 0.48 } }, -- walkable high ground, paler than the rock below it
        path   = { color = { 0.42, 0.30, 0.18 } }, -- dirt trail
        bridge = { color = { 0.55, 0.40, 0.22 } },
        river  = { color = { 0.18, 0.34, 0.55 } }, -- river
        water  = { color = { 0.36, 0.60, 0.66 } }, -- the wadeable kind: shallower and greener than the river
    },
}
