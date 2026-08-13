-- Biome blueprint. Volcanic ground is the tightest walkable maze the game draws -- fissured rock with
-- flows running through the gaps. Distinct from the underworld, which is the Gate's own place and
-- reached once: this is a surface a quest can be set on.
--
-- Its blocker is `lava` rather than `obstacle` (models/arena.lua), and that one substitution is the
-- whole board. Lava is impassable but does NOT block a line of sight -- the only barrier in the game
-- that separates two lines without also hiding them from each other. Both sides spend the fight in
-- full view of an enemy they cannot reach except the long way round, which is a shape no other biome
-- can produce.
--
-- Signature ground: fire, which spreads on its own into anything `burnable`. The one seeded hazard that
-- does not stay where it was put.
return {
    name = "Volcanic",
    tileset = "volcanic", -- data/tilesets/volcanic.lua (art for this biome)
    layout = "rifts", -- wide fractures meeting at chambers (models/layouts/rifts.lua)
    spacing = 2, -- kept for the river band; the carve no longer reads it
    rivers = { min = 2, max = 3 }, -- flows, not water; the bridges over them are the map's real doors
    hazard = { id = "hazard_fire", min = 1, max = 2 },
}
