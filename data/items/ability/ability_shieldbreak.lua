-- Shieldbreak: the Vanguard (knight x rogue) does not hold a line, it breaks one. A shoving blow that
-- knocks a foe back two tiles and leaves it Sundered (data/status/status_sundered.lua) -- every guard,
-- reflex and trait it carries goes quiet -- punching a hole the party pours through. The knight half of
-- Breach: sloth's wall mechanics turned outward, against someone else's wall.
local Curve = require("models.curve")

return {
    name = "Shieldbreak",
    description = "Knockback 2 and inflicts Sundered.",
    flavor = "A shield is only worth what the arm behind it still believes. This unteaches the belief.",
    sprite = "assets/items/ability_shieldbreak.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "knight",
    discipline = "vanguard", -- knight x rogue; the Breach mechanic's first stock
    price = 280,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            -- The Sunder rides the blow, so it lands on whoever the strike hits -- a guardian who steps
            -- in front of it is the one broken open.
            fx.damage(fx.target, { inflicts = "status_sundered" })
            fx.knockback(fx.target, 2, { amount = 0 })
        end,
    },
}
