-- HEAT OF THE DAY: the Noonday Demon's own blow (data/characters/character_noonday_demon.lua; "Sloth's Bestiary",
-- 2026-10-04, slice C). The noon sun laid on whoever is nearest. A demon's blows burn, and the channel is not
-- moved: a physical blow with fire on it (docs/bestiary.md).
local Curve = require("models.curve")

return {
    name = "Heat of the Day",
    description = "Strikes an adjacent foe.",
    flavor = "Not hot, exactly. Just enough that nothing seems worth getting up for.",
    sprite = "assets/items/weapon_heat_of_the_day.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee", "fire" },
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
