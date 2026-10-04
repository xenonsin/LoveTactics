-- MOTH WINGS: the Poppy-Moth's natural weapon ("Sloth's Bestiary", 2026-10-04). A soft buffet and nothing more: the
-- moth's danger is what comes off it when it is hit (trait_poppy_dust), never what it does.
local Curve = require("models.curve")

return {
    name = "Moth Wings",
    description = "A weak buffet to an adjacent foe.",
    flavor = "Powder on everything it touches, and it touches everything.",
    sprite = "assets/items/weapon_moth_wings.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
