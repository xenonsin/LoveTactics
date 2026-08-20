-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
local Curve = require("models.curve")

return {
    name = "Iron Plate",
    description = "Heavy armor. Physical blows glance away.",
    flavor = "The most steel a body can carry, and the Bastion will sell you every ounce of it.",
    sprite = "assets/items/iron_plate.png",
    type = "armor",
    class = "fighter",
    price = 475,
    unlockQuests = 3,
    -- Heavy tier: the most steel a body can carry, and it shows in the pace.
    bonus = { defense = Curve.ramp(1, 14), movement = -2 },
    resist = { physical = 4, slash = 3, pierce = 4 },
}
