-- WHITEOUT CLOAK: the Dread of the Whiteout's trophy (data/characters/character_dread_of_the_whiteout.lua), on the
-- Ninja's shelf. Approved 2026-10-04 on "Sloth's Bestiary", slice A. Her whiteout worn (trait_whiteout): Unseen to
-- foes more than 2 tiles away, and Limned, lit or within 2 is seen as anybody is.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Whiteout Cloak",
    description = "Unseen to foes more than 2 tiles away.",
    flavor = "Grey on white on grey. Archers hate it; the ninja who wears it has stopped noticing archers.",
    sprite = "assets/items/armor_whiteout_cloak.png",
    type = "armor",
    tags = { "cloth" },
    class = "ninja",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_whiteout" },
    bonus = { magicDefense = Curve.ramp(3, 13), movement = -1 },
}
