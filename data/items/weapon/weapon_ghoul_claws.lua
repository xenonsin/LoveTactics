local Curve = require("models.curve")

-- GHOUL CLAWS: every hit a small Stun (a shove down the turn order), and a critical one a paralysis
-- (`critMagnitude`, read where a carried rider lands). The ghoul's lost time, told as initiative.
return {
    name = "Ghoul Claws",
    description = "Inflicts a small Stun; a critical hit Stuns hard.",
    flavor = "Whatever is under the nails does the rest.",
    sprite = "assets/items/weapon_ghoul_claws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = { id = "status_stun", magnitude = 2, critMagnitude = 8 } })
        end,
    },
}
