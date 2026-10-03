-- HEAT SHIMMER: the Mirage's own blow (data/characters/character_mirage.lua; "Envy's Bestiary", round 1). The real
-- one's touch is the desert's heat; its illusions swing the same arm and land nothing (Combat.dealFlatDamage), so
-- the only blow on the board that hurts is the one thrown by the body worth finding.
local Curve = require("models.curve")

return {
    name = "Heat Shimmer",
    description = "Burns an adjacent foe.",
    flavor = "It is exactly as hot as it looks. The other three are not.",
    sprite = "assets/items/weapon_heat_shimmer.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "fire", "magical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
