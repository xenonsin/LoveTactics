-- FLAME LASH: the Balor's own blow (data/characters/character_balor.lua; "The Crown's Bestiary", slice B, 2026-10-09).
-- The great fire demon's whip. A demon's blow burns: a physical lash with fire on it (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Flame Lash",
    description = "Lashes a foe within 2.",
    flavor = "The crack arrives a moment after the burn does.",
    sprite = "assets/items/weapon_flame_lash.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(14, 26),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
