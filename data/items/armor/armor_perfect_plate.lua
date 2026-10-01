-- PERFECT PLATE: Superbia's Flawless Form for a person (reviewed over three rounds, "Pride's Generals"). No single
-- blow takes more than a quarter of the bearer's max health (trait_flawless_form at `woundCap = 0.25`).
--
-- A Knight's plate, because the knight is the one who is meant to still be standing after the worst blow of the
-- fight: the rule turns a one-shot into four. Heavy, so it pays two squares (docs/classes.md).
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Perfect Plate",
    description = "No single blow can take more than a quarter of your health.",
    flavor = "Not a dent in it. Not because nothing has hit it.",
    sprite = "assets/items/armor_perfect_plate.png",
    type = "armor",
    tags = { "heavy", "plate", "holy" },
    class = "knight",
    unlockLevel = 13,
    unstocked = true,
    bonus = { defense = Curve.ramp(4, 14), movement = -2 },
    traits = { "trait_flawless_form" },
    traitParams = { woundCap = 0.25 },
}
