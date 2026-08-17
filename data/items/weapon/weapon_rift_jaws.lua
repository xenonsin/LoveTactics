-- The Unquenched's jaws, and the Rift-Born's, both -- a wide bite off a body that stands on four tiles.
--
-- `front`, width 3, for the same reason the Sated's bulk sweeps: a four-tile body reaching out to poke
-- one knight reads wrong. What a thing that size does is occupy the argument.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Rift Jaws",
    description = "Sweeps everything in front of it, burning what it catches.",
    flavor = "The rift did not make it. The rift is simply where it stopped going down.",
    sprite = "assets/items/rift_jaws.png",
    type = "weapon",
    tags = { "natural", "fire", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(12, 22),
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "status_burn")
            end
        end,
    },
}
