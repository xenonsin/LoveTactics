-- MANA EDGE: the Lesser Archon's trophy (data/characters/character_lesser_archon.lua; "The Crown's Bestiary", slice
-- A, 2026-10-09). The body's blade lands on Magic Defense; carried out, the edge lands on whichever of the two
-- defenses is lower and bites +3 (trait_mana_edge). A Battlemage's, because steel that strikes like a spell is what
-- that house is.
return {
    name = "Mana Edge",
    description = "Your blows strike whichever of the foe's defense or magic defense is lower, and deal +3 damage.",
    flavor = "Plate stops a sword and a ward stops a spell. Very little stops a thing that is honestly both.",
    sprite = "assets/items/utility_mana_edge.png",
    type = "utility",
    tags = { "charm" },
    class = "battlemage",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_mana_edge" },
}
