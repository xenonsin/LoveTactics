-- Encounter blueprint. A reward stop rather than a fight: an unguarded cache
-- of loot. Uncommon (low weight) so it feels like a find. See
-- data/encounters/boar.lua for the shape.
return {
    name = "Treasure Chest",
    kind = "treasure",
    weight = 1,
    minPrestige = 1,
}
