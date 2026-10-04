-- YETI-HIDE MANTLE: the yeti's trophy (data/characters/character_yeti.lua), on the Hunter's shelf. Approved
-- 2026-10-04 on "Sloth's Bestiary", slice A. The yeti's roar, smaller: the same rule (trait_whiteout_roar) handed
-- a radius of 3 and only the nearest lonely foe through `traitParams`, as the Peacock's Train is handed the gaze.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Yeti-Hide Mantle",
    description = "At the start of your turn, the nearest foe within 3 with no ally beside it is Rooted.",
    flavor = "A hunter in this looks, from far enough off, like the last thing a straggler sees.",
    sprite = "assets/items/armor_yeti_hide_mantle.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_whiteout_roar" },
    traitParams = { radius = 3, nearest = true },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
}
