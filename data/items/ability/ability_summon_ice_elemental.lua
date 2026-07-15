-- Bind an ice elemental to the field. See ability_summon_fire_elemental.lua for how the reservation,
-- scaling, duration and one-at-a-time rule work. A slow, hardy wall of ice.
return {
    name = "Summon Ice Elemental",
    description = "Bind an ice elemental to the field for a time, one at a time. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_ice_elemental.png",
    type = "ability",
    tags = { "summon", "ice" },
    class = "mage",
    price = 450,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            fx.summon("ice_elemental", fx.tx, fx.ty, {
                scaling = { health = 2, magicDamage = 0.4 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
