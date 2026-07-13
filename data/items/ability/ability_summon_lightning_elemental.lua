-- Bind a lightning elemental to the field. See ability_summon_fire_elemental.lua for how the
-- reservation, scaling, duration and one-at-a-time rule work. A frail but hard-hitting glass cannon.
return {
    name = "Summon Lightning Elemental",
    description = "Bind a lightning elemental to the field for a time, one at a time. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_lightning_elemental.png",
    type = "ability",
    tags = { "summon", "lightning" },
    class = "mage",
    price = 460,
    repRank = 3,
    activeAbility = {
        name = "Summon Lightning Elemental",
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        power = { 12, 13, 14, 16, 17, 18, 19, 20, 22, 23, 24 },
        effect = function(fx)
            fx.summon("lightning_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                power = fx.power,
                duration = 24,
            })
        end,
    },
}
