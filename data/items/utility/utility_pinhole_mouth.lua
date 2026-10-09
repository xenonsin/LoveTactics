-- PINHOLE MOUTH: the Hungry Ghost's trophy, on the Spellbreaker's shelf. Approved 2026-10-09 ("The Crown's
-- Bestiary", slice E). The ghost's appetite narrowed to a foe's healing (trait_pinhole_mouth, models/lethe.lua):
-- stand beside their healer's patient and the heal is yours.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Pinhole Mouth",
    description = "Heals that land on foes within 2 of you heal you instead.",
    flavor = "In the old stories it was a punishment. Worn on a string, it is a habit.",
    sprite = "assets/items/utility_pinhole_mouth.png",
    type = "utility",
    tags = { "charm" },
    class = "spellbreaker",
    unlockLevel = 14,
    unstocked = true,
    traits = { "trait_pinhole_mouth" },
}
