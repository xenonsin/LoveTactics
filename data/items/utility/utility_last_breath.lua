-- LAST BREATH: the Balor's trophy (data/characters/character_balor.lua; "The Crown's Bestiary", slice B, approved
-- 2026-10-09). The Balor's Death Throes handed over and drawn in: when the bearer falls it bursts in flame, fire to
-- every body within 2, either side (trait_hellfire_throes, `radius = 2`). A Bombardier's, because a body that goes
-- off when it drops is a charge that walks.
return {
    name = "Last Breath",
    description = "When you fall, you burst in flame: fire damage to every body within 2.",
    flavor = "Whatever kept the fire in, it was never you.",
    sprite = "assets/items/utility_last_breath.png",
    type = "utility",
    tags = { "charm", "fire" },
    class = "bombardier",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_hellfire_throes" },
    traitParams = { radius = 2, magnitude = 16 },
}
