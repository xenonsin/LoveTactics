-- A gorge-fly's bite: it takes almost nothing and it marks what it took from.
--
-- The swarm's whole job is to be the setup. Individually this does less damage than a party member
-- regenerates, which is deliberate -- what matters is the Bleed, because a bled body is one the Tallow
-- Hound behind it can finish, and a finished body is what Engorge is paid for
-- (data/traits/trait_engorge.lua).
--
-- So killing the flies is correct and killing them is also what feeds the hound. That tension IS the
-- Gluttony circle, stated in the cheapest body on the floor.
local Curve = require("models.curve")

return {
    name = "Gorge Bite",
    description = "Bites an adjacent foe and leaves Bleed.",
    flavor = "One is a nuisance. The nuisance is not what it is for.",
    sprite = "assets/items/gorge_bite.png",
    type = "weapon",
    tags = { "natural", "bite", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 3 },
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_bleed")
        end,
    },
}
