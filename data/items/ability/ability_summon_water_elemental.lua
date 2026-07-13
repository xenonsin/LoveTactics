-- Bind a water elemental to the field. One of the five elemental summons that join the mage's Fire
-- Elemental (data/items/ability/ability_summon_fire_elemental.lua) -- see it for how `reserve`,
-- `scaling`, `duration` and the one-at-a-time rule work. A sturdy body that leaves foes Wet.
return {
    name = "Summon Water Elemental",
    description = "Bind a water elemental to the field for a time, one at a time. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_water_elemental.png",
    type = "ability",
    tags = { "summon", "water" },
    class = "mage",
    price = 440,
    repRank = 3,
    activeAbility = {
        name = "Summon Water Elemental",
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        power = 12,
        effect = function(fx)
            fx.summon("water_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                power = fx.power,
                duration = 24,
            })
        end,
    },
}
