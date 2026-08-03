-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag (e.g. a "slash" attack).
local Curve = require("models.curve")

return {
    name = "Leather Armor",
    description = "Medium armor. Turns aside a glancing blade.",
    flavor = "Boiled hide, cut by someone who has seen what happens without it.",
    sprite = "assets/items/leather.png",
    type = "armor",
    -- Medium tier: modest bulk, one square slower. Defense and resists are per-level tables (levels
    -- 0..10) the forge steps up; the movement penalty is flat (a single number never scales).
    bonus = {
        defense = Curve.ramp(4, 14),
        movement = -1,
    },
    resist = {
        slash    = Curve.paired(3, 8),
        physical = Curve.paired(2, 7),
    },
}
