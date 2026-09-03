-- Iron Fist: hands hardened past a weapon's need. A passive "fist" charm that pours flat damage into
-- the bearer's bare-handed strike (`unarmedBonus.damage`, folded onto the hidden unarmed weapon in
-- models/combat.lua). It does nothing for a crafted blade -- only the fist. Stack it with the other
-- fist charms (Shadow, Swift, Drunken) to build a monk whose punch outclasses a sword.
local Curve = require("models.curve")

return {
    name = "Iron Fist",
    description = "Adds damage to bare-handed strikes. Does nothing for a weapon.",
    flavor = "Hands hardened past a weapon's need. The Cathedral does not ask how, and is not told.",
    sprite = "assets/items/iron_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    discipline = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    price = 330,
    unlockQuests = 3,
    unarmedBonus = { damage = Curve.ramp(4, 14) },
    -- a gauntlet guards the hand; the Power is unarmedBonus's, not a weapon's
    bonus = { defense = 1 },
}
