local Curve = require("models.curve")

-- GHOUL'S BITE: the Ghoul's. The claw's paralysis at full strength, and the feeding: a bite that Stuns
-- hard and heals you for half the damage it drew. Barbarian stock, beside the Bottomless Gut.
return {
    name = "Ghoul's Bite",
    description = "Bites an adjacent foe, Stunning it hard, and heals you for half the damage dealt.",
    flavor = "You will not like how it tastes. You will like how it feels afterwards, and that is worse.",
    sprite = "assets/items/ability_ghouls_bite.png",
    type = "ability",
    tags = { "physical", "slash" },
    class = "barbarian",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cooldown = 10,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            local d = fx.damage(fx.target, { inflicts = { id = "status_stun", magnitude = 10 } })
            if d and d > 0 then fx.heal(fx.user, math.floor(d / 2)) end
        end,
    },
}
