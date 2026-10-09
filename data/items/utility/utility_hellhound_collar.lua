-- HELLHOUND COLLAR: the Hellhound's trophy ("The Crown's Bestiary", slice C, approved 2026-10-09). The hound's rule
-- for a Beastmaster's animals: whatever the bearer summoned walks through fire on the ground unharmed and heals 3 a
-- turn it ends in it (trait_hearth_collar). Without the hound's +3, which is the hound's.
return {
    name = "Hellhound Collar",
    description = "Your beasts and summons are unharmed by fire on the ground and heal 3 standing in it.",
    flavor = "Spiked on the inside. Whatever wore it last did not mind.",
    sprite = "assets/items/utility_hellhound_collar.png",
    type = "utility",
    tags = { "charm", "fire" },
    class = "beastmaster",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_hearth_collar" },
}
