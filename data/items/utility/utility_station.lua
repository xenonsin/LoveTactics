-- STATION: one of the Apex Crystal's own (data/characters/character_apex_crystal.lua) (trait_station).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Station",
    description = "+3 Defense while a lower-level ally stands next to you.",
    flavor = "It is not arrogance if they are standing in front of you.",
    sprite = "assets/items/utility_station.png",
    type = "utility",
    class = "mage",
    unlockLevel = 14,
    unstocked = true,
    tags = { "protective" },
traits = { "trait_station" },
}
