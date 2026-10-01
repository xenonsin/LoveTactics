-- LIVERY OF THE HOUSE: the Elf Retainer's drop (data/characters/character_elf_retainer.lua). Approved 2026-09-30
-- ("Pride's Bestiary"). A house's colours, worn to be seen unmarked: +3 Defense on top of the coat while the wearer
-- is at full health (trait_livery). Armour, so it costs its square.
--
-- `unstocked`: the body's own piece, visible on the knight's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Livery of the House",
    description = "While at full health, increase defense by 3.",
    flavor = "A close-cut coat in a house's green and white, brushed every morning so no mark shows.",
    sprite = "assets/items/armor_livery_of_the_house.png",
    type = "armor",
    tags = { "cloth" },
    class = "knight",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_livery" },
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
}
