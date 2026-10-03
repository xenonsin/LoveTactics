-- NAZAR: the Evil Eye's trophy (data/characters/character_evil_eye.lua), on the Exorcist's shelf. Approved on
-- "Envy's Bestiary", round 1. The blue eye a household hangs against the eye: the first debuff or curse that would
-- land on its bearer each fight is turned aside (trait_nazar; one latch for both, models/envy_oneoffs.lua).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Nazar",
    description = "The first debuff or curse that would land on you each fight is turned aside.",
    flavor = "Glass, blue, and older than the Cathedral. The exorcists carry it anyway and do not discuss why.",
    sprite = "assets/items/utility_nazar.png",
    type = "utility",
    tags = { "ward" },
    class = "exorcist",
    unlockLevel = 11,
    unstocked = true,
    traits = { "trait_nazar" },
}
