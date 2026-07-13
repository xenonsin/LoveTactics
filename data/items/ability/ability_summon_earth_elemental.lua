-- Bind an earth elemental to the field. See ability_summon_fire_elemental.lua for how the
-- reservation, scaling, duration and one-at-a-time rule work. The tank of the set -- and the only one
-- that fights physically, so its Power scales `damage` rather than `magicDamage`.
return {
    name = "Summon Earth Elemental",
    description = "Bind an earth elemental to the field for a time, one at a time. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_earth_elemental.png",
    type = "ability",
    tags = { "summon", "earth" },
    class = "mage",
    price = 470,
    repRank = 4,
    activeAbility = {
        name = "Summon Earth Elemental",
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        power = { 12, 13, 14, 16, 17, 18, 19, 20, 22, 23, 24 },
        effect = function(fx)
            fx.summon("earth_elemental", fx.tx, fx.ty, {
                scaling = { health = 3, damage = 0.5 },
                power = fx.power,
                duration = 24,
            })
        end,
    },
}
