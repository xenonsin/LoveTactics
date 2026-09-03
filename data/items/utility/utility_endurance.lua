-- Endurance: a deeper well of wind. A passive charm that raises the bearer's maximum stamina
-- (`maxBonus.stamina`, folded into Combat.unreservedMax). Stamina refills to its full effective ceiling
-- at the start of each battle, so unlike Toughness this bigger pool is usable from the opening bell --
-- more strikes and abilities before you have to Focus or wait to recover.
local Curve = require("models.curve")

return {
    name = "Endurance",
    description = "Raises your maximum stamina.",
    flavor = "The Lodge measures a hunter in hours, not in blows.",
    sprite = "assets/items/endurance.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    price = 80,
    unlockQuests = 0,
    maxBonus = { stamina = Curve.ramp(15) },
    -- a deeper pool is a body that lasts
    bonus = { defense = 1 },
}
