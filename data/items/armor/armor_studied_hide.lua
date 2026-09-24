-- STUDIED HIDE: lifted off Gula, and it kept the half of her rule that LEARNS (data/traits/trait_studied.lua).
-- Every hit you take teaches it that hit's damage kind, and the next of that kind lands on a coat that
-- already knows it (Resistant, -4) -- until something different arrives and it learns that instead.
--
-- Settled on review 2026-09-23 with the note "each hit grants you resistance": not the three-hit ramp first
-- pitched, but her rule exactly, one blow at a time. The same counterplay she has, pointed at whoever is
-- wearing it: a line that hits you with the same thing twice has thrown a weaker second blow, and an enemy
-- company that mixes its damage never gets read.
--
-- A hide, and the Lodge's (`hunter`, the shelf Ravener's Hide sits on) -- a tank's coat that gets better the
-- longer the other side does one thing. A general's find: `unstocked`, shown on the rack and never sold.
local Curve = require("models.curve")

return {
    name = "Studied Hide",
    description = "Each hit grants resistance to its damage type, replacing the last.",
    flavor = "It was cut from something that had been cut before, by everything, once.",
    sprite = "assets/items/armor_studied_hide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    unlockLevel = 2,
    unstocked = true,
    traits = { "trait_studied" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
