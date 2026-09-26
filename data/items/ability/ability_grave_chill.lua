local Curve = require("models.curve")

-- GRAVE-CHILL: Vesh's bolt. Dark damage, and the body it strikes is Interred (status_interred): every heal
-- aimed at it lands as a wound for about a turn and a half. The reflex to heal the one who is falling is
-- the wrong move for a moment -- which is how a body goes down beside a ghoul.
return {
    name = "Grave-Chill",
    description = "Deals dark damage to a foe and inflicts Interred.",
    flavor = "The cold of a room nobody has opened in four hundred years, sent on ahead.",
    sprite = "assets/items/ability_grave_chill.png",
    type = "ability",
    class = "creature",
    tags = { "dark", "magical" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 6 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            fx.damage(fx.target)
            if fx.target and fx.target.alive then fx.applyStatus(fx.target, "status_interred") end
        end,
    },
}
