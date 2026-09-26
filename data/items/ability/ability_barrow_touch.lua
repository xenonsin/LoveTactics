local Curve = require("models.curve")

-- BARROW TOUCH: the Barrow-Wight's, and its touch unchanged -- a cold dark touch that puts a foe to Sleep,
-- on a two-turn cooldown, warded like any Sleep. Shaman stock: a hand that sends a body somewhere else.
return {
    name = "Barrow Touch",
    description = "A cold touch that deals dark damage and puts an adjacent foe to Sleep.",
    flavor = "The wight's hand, borrowed. Give it back before it gets used to you.",
    sprite = "assets/items/ability_barrow_touch.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "shaman",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cooldown = 10,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            fx.damage(fx.target)
            if fx.target and fx.target.alive then fx.applyStatus(fx.target, "status_sleep") end
        end,
    },
}
