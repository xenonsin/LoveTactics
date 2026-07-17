-- Bind a wind elemental to the field. See ability_summon_fire_elemental.lua for how the reservation,
-- scaling, duration and one-at-a-time rule work. A blindingly fast scout -- frail, but everywhere.
return {
    name = "Summon Wind Elemental",
    description = "Binds a wind elemental for a time. One at a time; reserves a quarter of your max mana.",
    flavor = "Frail, and everywhere. The Arcanum has never once persuaded one to sit still.",
    sprite = "assets/items/ability_summon_wind_elemental.png",
    type = "ability",
    tags = { "summon", "wind" },
    class = "mage",
    price = 440,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            fx.summon("character_wind_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.4 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
