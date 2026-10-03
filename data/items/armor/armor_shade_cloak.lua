-- SHADE CLOAK: the Shade's trophy (data/characters/character_shade.lua), on the Assassin's shelf. Approved on
-- "Envy's Bestiary", round 1. The half of the Shade's rule a company can wear (trait_shade_cloak): beside a wall
-- the bearer is Unseen. Open ground does not Limn the wearer; the cloak promises the shadow and nothing else.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Shade Cloak",
    description = "While you stand beside a wall, you are Unseen.",
    flavor = "It still remembers being cast by somebody, and it keeps trying to get back to the wall.",
    sprite = "assets/items/armor_shade_cloak.png",
    type = "armor",
    tags = { "cloth" },
    class = "assassin",
    unlockLevel = 11,
    unstocked = true,
    traits = { "trait_shade_cloak" },
    bonus = { magicDefense = Curve.ramp(3, 13), movement = -1 },
}
