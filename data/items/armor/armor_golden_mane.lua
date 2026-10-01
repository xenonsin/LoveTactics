-- GOLDEN MANE: the Lion's trophy (data/characters/character_lion.lua), on the Knight's shelf. Approved 2026-09-30
-- on Pride's bestiary review. His roar worn as a coat: a kill the bearer makes heals every ally within 2 by 10%
-- and leaves every foe within 2 Rattled (trait_golden_mane).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Golden Mane",
    description = "When you make a kill, allies within 2 heal 10% and foes within 2 are Rattled.",
    flavor = "Worn over the shoulders, it makes a knight look like she has already won. Then she has to.",
    sprite = "assets/items/armor_golden_mane.png",
    type = "armor",
    tags = { "hide" },
    class = "knight",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_golden_mane" },
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
}
