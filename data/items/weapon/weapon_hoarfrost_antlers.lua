-- The Winter Hart's antlers, and the Long Winter's reach -- a wide sweep off a four-tile body.
--
-- `front`, width 3, for the reason every apex weapon in this pass sweeps: a body standing on four tiles
-- reaching out to poke one knight reads wrong. It freezes what it catches, because everything in this
-- stratum costs turns rather than health.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Hoarfrost Antlers",
    description = "Sweeps everything in front of it and leaves Freeze.",
    flavor = "Something walked north until it stopped being an animal, and kept walking.",
    sprite = "assets/items/hoarfrost_antlers.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(11, 21),
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "status_freeze")
            end
        end,
    },
}
