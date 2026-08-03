-- A zombie's natural weapon: slow, clumsy, but strong. What a raised corpse swings (Raise Dead,
-- data/items/ability/ability_raise_dead.lua). `noSteal` -- and pointless to steal besides.
local Curve = require("models.curve")

return {
    name = "Rotting Claws",
    description = "Mauls an adjacent foe.",
    flavor = "Slow, clumsy, strong. Whatever it was before, it has stopped asking questions.",
    sprite = "assets/items/rotting_claws.png",
    type = "weapon",
    tags = { "natural", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5, -- slow and lurching
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(7),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
