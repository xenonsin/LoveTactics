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
    -- Medium tier: modest bulk, one square slower. Defense is the per-level table (levels 0..10) the forge
    -- steps up; the resists and the movement penalty are flat single numbers, which never scale -- what
    -- boiled hide turns aside is what it is, and the forge sells the bulk (models/curve.lua).
    bonus = {
        defense = Curve.ramp(2, 12),
        movement = -1,
    },
    resist = {
        slash = 3,
        physical = 2,
    },
}
