-- PEACOCK'S TRAIN: the Peacock-Basilisk's trophy (data/characters/character_peacock_basilisk.lua), on the
-- Rogue's shelf. Approved 2026-09-30 on Pride's bestiary review. The bird's gaze, smaller and kinder: foes within
-- 2 that end a turn without attacking the bearer are Rattled rather than Stunned. The same rule
-- (trait_the_admired_gaze), handed a smaller radius and a lighter status through `traitParams`.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Peacock's Train",
    description = "Foes within 2 that end a turn without attacking you are Rattled.",
    flavor = "A rogue's whole trade is being where nobody is looking. This is the other trade.",
    sprite = "assets/items/utility_peacocks_train.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_the_admired_gaze" },
    traitParams = { radius = 2, status = "status_rattled", duration = 8 },
}
