-- SERPENT HAIR: Medusa's own bite (data/characters/character_medusa.lua) -- the snakes she wears for hair, which
-- strike whoever comes close enough to be bitten. Inflicts Poison. Natural, unstealable and on no shelf; what she
-- drops is Serpent Locks, the same snakes cut into a poisoner's coat.
local Curve = require("models.curve")

return {
    name = "Serpent Hair",
    description = "Inflicts Poison.",
    flavor = "Every one of them is looking at you. That is not the part to worry about.",
    sprite = "assets/items/weapon_serpent_hair.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_poison" })
        end,
    },
}
