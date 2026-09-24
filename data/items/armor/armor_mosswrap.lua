-- MOSSWRAP: what comes off a moss slime (data/characters/character_moss_slime.lua), and the only place
-- it comes from.
--
-- THE SLIME'S RULE, WORN: what comes apart tries to come back together. The first time each battle the
-- wearer is struck below half health, a piece of the moss sloughs off and stands up beside them
-- (trait_slough) -- a Moss Sloughling carrying a fifth of their health, which fights, walks home, and
-- gives back what it has left. The defence is ordinary light armour; the rule is the reason to wear it.
--
-- `unstocked`: the slime's own piece, visible on the Lodge's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Mosswrap",
    description = "Once per battle, when struck below half health, a moss sloughling sloughs off beside you.",
    flavor = "It was alive when you put it on. It is mostly still alive.",
    sprite = "assets/items/armor_mosswrap.png",
    type = "armor",
    tags = { "hide", "earth" },
    class = "hunter",
    unlockLevel = 1,
    unstocked = true,
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
    traits = { "trait_slough" },
}
