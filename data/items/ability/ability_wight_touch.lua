local Curve = require("models.curve")

-- THE WIGHT'S TOUCH: the barrow-wight lays you out for the grave. A cold dark touch, and the body it
-- touches sleeps (status_sleep: far down the turn order until something hits it) -- which is exactly what
-- the ghouls are waiting for. On a two-turn cooldown and warded like any Sleep (magical, halved on every
-- repeat): the review read Sleep as "might be too powerful", and those two are the answer.
-- The creature twin of the Shaman's Barrow Touch, which is what it drops.
return {
    name = "Barrow-Touch",
    description = "A cold touch that puts an adjacent foe to Sleep.",
    flavor = "It does not want you dead. It wants you still, and dressed, and quiet.",
    sprite = "assets/items/ability_wight_touch.png",
    type = "ability",
    class = "creature",
    tags = { "dark", "magical" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cooldown = 10, -- two turns
        cost = { stat = "mana", amount = 6 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            fx.damage(fx.target)
            if fx.target and fx.target.alive then fx.applyStatus(fx.target, "status_sleep") end
        end,
    },
}
