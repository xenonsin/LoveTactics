-- WIND BLADES: the Hornless Twin's cast. Approved 2026-09-26 ("The Oni of Wrath"): "wind blades." It costs mana,
-- which she has to draw from her sister (status_borrowed_horn) -- so the cast is the half of the pair rule the
-- company can switch off by Silencing, snapping or felling the horned twin.
local Curve = require("models.curve")

return {
    name = "Wind Blades",
    description = "Cuts a foe within 4 with the wind.",
    flavor = "She never lifts a hand. The air does it for her, and it has never once asked why.",
    sprite = "assets/items/ability_wind_blades.png",
    type = "ability",
    tags = { "wind", "slash", "magical" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 3,
        requiresSight = true,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(10, 22),
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
        end,
    },
}
