-- Bind a fire elemental to the field. The mage's counterpart to Summon Wolf: the same reservation
-- bargain (a quarter of maximum mana, spent on the cast and locked away for as long as the elemental
-- stands), placed at arm's length rather than adjacent, and scaling its magicDamage rather than its bite.
-- See data/items/ability/ability_summon_wolf.lua for how `reserve` and `scaling` work.
return {
    name = "Summon Fire Elemental",
    description = "Bind a fire elemental to the field. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_fire_elemental.png",
    type = "ability",
    tags = { "summon", "fire" },
    activeAbility = {
        name = "Summon Fire Elemental",
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        power = 12,
        effect = function(fx)
            fx.summon("fire_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                power = fx.power,
            })
        end,
    },
}
