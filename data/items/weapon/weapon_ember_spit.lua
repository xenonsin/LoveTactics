-- An ember-spit's spit. A short bolt of fire, and the least interesting thing about the body carrying it.
--
-- The Wrath swarm's whole worth is what it leaves behind when it dies (data/traits/trait_cinderfall.lua)
-- -- fire on the tile, which takes ground away from you every time you clear one. So its weapon is a
-- cheap ranged poke that keeps it at a distance and gets it killed out where the fire is inconvenient.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Ember Spit",
    description = "Spits fire at a foe, burning it.",
    flavor = "It has one idea, it is not a good one, and it will have it right up until the end.",
    sprite = "assets/items/ember_spit.png",
    type = "weapon",
    tags = { "natural", "fire", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_burn")
        end,
    },
}
