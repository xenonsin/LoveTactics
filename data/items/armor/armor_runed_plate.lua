-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
local Curve = require("models.curve")

return {
    name = "Runed Plate",
    description = "Heavy armor. Guards against blade and spell alike.",
    flavor = "The sigils are real. The Bastion charges you for the etching, not the warding.",
    sprite = "assets/items/runed_plate.png",
    type = "armor",
    class = "knight",
    price = 610,
    unlockQuests = 4,
    -- Heavy tier: trades a little raw steel for a genuine guard against magic.
    bonus = { defense = Curve.ramp(6, 16), magicDefense = Curve.ramp(3, 13), movement = -2 },
    resist = { physical = 3, magical = 3 },
}
