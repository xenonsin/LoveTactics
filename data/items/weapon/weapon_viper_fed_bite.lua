-- VIPER-FED BITE: the Wasting One's own blow (data/characters/character_wasting_one.lua; "Envy's Bestiary", round 4).
-- Ovid's Envy feeds on vipers' flesh, and her teeth are green with it. A demon's bite burns -- a physical blow with
-- fire on it, never moved to the magical channel (tests/bestiary_spec.lua's demon rule).
local Curve = require("models.curve")

return {
    name = "Viper-Fed Bite",
    description = "Bites an adjacent foe.",
    flavor = "The teeth are green, and the breath behind them is worse.",
    sprite = "assets/items/weapon_viper_fed_bite.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
