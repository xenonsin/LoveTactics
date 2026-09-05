-- A cinder-kin's brand: a burning arm, swung.
--
-- The Wrath circle's line weapon, carried by the kin and by the Anvil above it. It burns, because
-- everything in this stratum burns -- and Burn ticking on your line is what keeps the fire the swarm
-- leaves behind relevant after the swarm is dead.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Cinder Brand",
    description = "Strikes an adjacent foe, burning it.",
    flavor = "Whatever it was made of has mostly finished burning. It has not finished swinging.",
    sprite = "assets/items/cinder_brand.png",
    type = "weapon",
    class = "creature",
    dropTier = 7,
    tags = { "natural", "fire", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_burn")
        end,
    },
}
