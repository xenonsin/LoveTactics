-- Spire biome tileset (art only). Tile types + walkability are universal and live in
-- models/tileset.lua; here we only name the spritesheet and the pre-art fallback colours so a spire
-- map reads visibly different from the castle it was cut out of.
--
-- IT IS NOT A CASTLE RE-SKIN, and the palette is where that has to be true first. Pride held the
-- castle until Lust took it (models/descent.lua's Descent.SINS), and two strata a player cannot tell
-- apart on a board are one stratum with two names -- so this reads as ALTITUDE where the castle reads
-- as enclosure: pale cut stone bleached by weather, open sky where the keep had ceilings, and a drop
-- instead of a moat.
--
-- THE SAME RESKIN THE CASTLE MAKES, for the same reason. `mountain` is the board's impassable,
-- sight-blocking solid; indoors the castle calls it a rampart because it is what the room is made of.
-- Up here it is the tower's own shaft -- the column the stair winds around, which you go round rather
-- than through. Nothing about the tile changes: same cost, same block, and a flier still clears it,
-- because the rule belongs to models/terrain.lua and a biome only dresses what it finds.
return {
    image = "assets/overworld/spire.png",
    tileSize = 16,
    tiles = {
        thicket = { color = { 0.30, 0.29, 0.26 } }, -- weathered stone block (the "fill")
        -- No `color`: the board takes an impassable tile's tone from the `rock` art role
        -- (ui/battle_map.lua's ART), so a colour written here would never be read.
        mountain = { skin = "masonry", name = "Shaft",
                     desc = "The tower's own column, cut and set. Blocks movement and line of sight -- only a flier gets round it." },
        grass  = { color = { 0.44, 0.44, 0.40 } }, -- wind-scoured terrace
        rock   = { color = { 0.62, 0.60, 0.54 } }, -- pale dressed stone
        path   = { color = { 0.55, 0.52, 0.47 } }, -- worn stair tread
        bridge = { color = { 0.48, 0.44, 0.36 } }, -- a span between towers
        river  = { color = { 0.34, 0.38, 0.46 } }, -- open air: the drop between spans
    },
}
