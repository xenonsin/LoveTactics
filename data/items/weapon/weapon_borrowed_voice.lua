-- BORROWED VOICE: the Echo's own (data/characters/character_echo.lua; "Envy's Bestiary", 2026-10-03, slice C).
-- She has no words of her own, so what she throws is somebody else's, half-heard: a thin magical blow on the wind
-- from three tiles. Her rule is the repeat (utility_only_repeats); this is only what she does between casts.
local Curve = require("models.curve")

return {
    name = "Borrowed Voice",
    description = "Strikes a foe within 3.",
    flavor = "The last thing you said, said wrong.",
    sprite = "assets/items/weapon_borrowed_voice.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "magical", "wind", "ranged" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 3 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
