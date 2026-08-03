-- Drunken Fist: the sloppier the stance, the heavier the blow. A passive "fist" charm that adds damage
-- to the bearer's bare-handed strike ONLY while it is Drunk (data/status/drunk.lua) -- the bonus is
-- keyed off the drunk flag in the unarmed damage path (models/combat.lua). Pair it with Wine: get
-- drunk, and your punches turn savage; sober up, and it does nothing. A gambler's charm.
local Curve = require("models.curve")

return {
    name = "Drunken Fist",
    description = "Bare-handed strikes hit far harder while Drunk; nothing while sober.",
    flavor = "A gambler's charm, sold by a priest who has made his peace with the arrangement.",
    sprite = "assets/items/drunken_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    discipline = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    price = 200,
    unlockQuests = 3,
    unarmedBonus = { drunkDamage = Curve.ramp(6, 16) },
}
