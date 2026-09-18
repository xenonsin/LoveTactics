-- A wind elemental's natural weapon. A fast, cutting gust -- the quickest of the elemental strikes
-- (speed 1), matching the wind elemental's darting movement -- carrying the "wind" tag. `noSteal`:
-- there is nothing solid to lift.
local Curve = require("models.curve")

return {
    name = "Gale Fists",
    description = "Slashes an adjacent foe with a cutting gust.",
    flavor = "There is nothing solid to lift off it, and nothing solid to strike back at.",
    sprite = "assets/items/gale_fists.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "wind", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 1,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
