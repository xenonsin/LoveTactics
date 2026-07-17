-- Bind an ice elemental to the field. See ability_summon_fire_elemental.lua for how the reservation,
-- scaling, duration and one-at-a-time rule work. A slow, hardy wall of ice.
return {
    name = "Summon Ice Elemental",
    description = "Binds an ice elemental for a time. One at a time; reserves a quarter of your max mana.",
    flavor = "A slow, hardy wall of ice with nowhere in particular it needs to be.",
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
            fx.summon("character_ice_elemental", fx.tx, fx.ty, {
                scaling = { health = 2, magicDamage = 0.4 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
