-- A coffer-crawler's shell, swung -- and the coin inside it, which is the point.
--
-- The Greed line body is armoured in what it has swallowed, so breaking the shell PAYS: the bounty here
-- is on the crawler's own death rather than on its swing, which makes it the one body in the circle that
-- is worth killing rather than merely necessary.
--
-- That is the sin as a decision. Everything else on this floor takes from you; this one gives it back,
-- if you can afford the turns.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Coffer Shell",
    description = "Strikes an adjacent foe with its own hoarded weight.",
    flavor = "Four hundred years of other people's savings, worn as a back.",
    sprite = "assets/items/coffer_shell.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
