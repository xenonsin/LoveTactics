-- A lightning elemental's natural weapon. A shocking strike that carries the "lightning" tag, so it
-- reaps the bonus damage on any foe left Wet (by rain, or by a water elemental's Tide Fists) -- the
-- water-and-lightning pairing the mage's kit is built around. `noSteal`: the storm is not yours to take.
local Curve = require("models.curve")

return {
    name = "Storm Fists",
    description = "Shocks an adjacent foe.",
    flavor = "The storm is not yours to take, and it has never been anyone's to keep.",
    sprite = "assets/items/storm_fists.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "lightning", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
