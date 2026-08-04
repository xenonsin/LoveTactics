-- The Forge: the city's one upgrade bench. Vendors sell; this is where every ladder is climbed and the
-- only door that spends materials (models/forge.lua, ui/panels/forge.lua). It opens with the city --
-- an upgrade station the player cannot reach is the same as no upgrade station, which is exactly what
-- the old unreachable blacksmith was.
--
-- Sits in the free card of the bottom row, between the Draft Yard and the Crucible.
return {
    name = "The Forge",
    order = 10,
    x = 195,
    y = 530,
    w = 270,
    h = 140,
    panel = "forge",
    unlockPrestige = 1,
}
