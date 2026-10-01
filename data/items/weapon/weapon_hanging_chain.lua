-- THE HANGING CHAIN: the Titan's own swing (data/characters/character_titan.lua). Approved 2026-09-30 on Pride's
-- bestiary review: "it moves only 1 tile a turn but its weapon reaches 2, and every blow shoves the target 2
-- tiles." The length of chain still hanging off its wrist, swung: reach 2, and the mace's folded shove
-- (opts.knockback), so a body driven into another body or a wall takes the collision as a mace's does.
--
-- A natural weapon: the Titan's own, unpriced and unstealable. What a company can carry away is the Titan's
-- Chain (weapon_titans_chain), which sweeps.
local Curve = require("models.curve")

return {
    name = "Hanging Chain",
    description = "Strikes a foe up to 2 tiles away and knocks it back 2. A collision hurts everyone in it.",
    flavor = "The gods kept the other end. It found a use for this one.",
    sprite = "assets/items/weapon_hanging_chain.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 5,
        requiresSight = true,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target, { knockback = { distance = 2, amount = fx.amount } })
        end,
    },
}
