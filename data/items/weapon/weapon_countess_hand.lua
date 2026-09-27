-- THE COUNTESS'S HAND: the Blood Countess's natural weapon (models/basin.lua). She does not cut so much as move
-- you: the blow opens a vein and THEN throws you two tiles, so the first thing the wound does is bleed into her
-- basin. The Bleed rides the blow (`inflicts`, landed before the shove -- Combat.dealFlatDamage), and the shove is
-- the Iron Mace's (`knockback`, 2 tiles, a collision hurts everyone in it).
local Curve = require("models.curve")

return {
    name = "Countess's Hand",
    description = "Inflicts Bleed, then Knockback 2.",
    flavor = "A gloved hand on your shoulder, and then you are somewhere else, and bleeding.",
    sprite = "assets/items/weapon_countess_hand.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(9, 21),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_bleed", knockback = { distance = 2, amount = fx.amount } })
        end,
    },
}
