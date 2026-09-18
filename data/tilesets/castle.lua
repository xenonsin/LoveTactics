-- Castle biome tileset (art only). Tile types + walkability are universal and
-- live in models/tileset.lua; here we only name the spritesheet and the pre-art
-- fallback colours (cold stone walls, flagstone floors, a dark moat) so a castle
-- map reads visibly different from the forest even before art exists.
--
-- AND ONE TILE IS RESKINNED. `mountain` is the board's impassable, sight-blocking solid, and in open
-- country it is exactly what it sounds like -- a rock face you go around. Inside a fortress the same
-- tile is the thing the room is MADE of, so here it draws set stone and is called a rampart. Nothing
-- about it changes: same cost, same block, and a flier still clears it, because the rule belongs to
-- models/terrain.lua and a biome only dresses what it finds.
--
-- It is NOT called a "wall", and the restraint is load-bearing. `models/wall.lua` walls are a
-- different thing that shares the word -- conjured, destructible, and the one blocker flight does not
-- open (the Illusory Wall) -- so a tile calling itself a wall would be making a claim about which of
-- the two it is, and getting it wrong in both directions.
return {
    image = "assets/overworld/castle.png",
    tileSize = 16,
    tiles = {
        thicket = { color = { 0.20, 0.20, 0.23 } }, -- stone wall block (the "fill")
        -- No `color`: the board takes an impassable tile's tone from the `rock` art role above
        -- (ui/battle_map.lua's ART), so a colour written here would never be read.
        mountain = { skin = "masonry", name = "Rampart",
                     desc = "Fortress stone, cut and set. Blocks movement and line of sight -- only a flier gets over it." },
        grass  = { color = { 0.24, 0.26, 0.22 } }, -- mossy stone
        rock   = { color = { 0.40, 0.40, 0.44 } }, -- lighter masonry
        path   = { color = { 0.46, 0.42, 0.37 } }, -- flagstone corridor
        bridge = { color = { 0.50, 0.38, 0.24 } }, -- timber drawbridge
        river  = { color = { 0.14, 0.24, 0.40 } }, -- moat
    },
}
