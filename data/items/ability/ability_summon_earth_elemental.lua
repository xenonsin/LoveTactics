-- Bind an earth elemental to the field. See ability_summon_fire_elemental.lua for how the
-- reservation, scaling, duration and one-at-a-time rule work. The tank of the set -- and the only one
-- that fights physically, so its Power scales `damage` rather than `magicDamage`.
return {
    name = "Summon Earth Elemental",
    description = "Binds an earth elemental for a time. One at a time; reserves a quarter of your max mana.",
    flavor = "The tank of the set, and the only one that argues with its fists rather than the weather.",
    sprite = "assets/items/ability_summon_earth_elemental.png",
    type = "ability",
    tags = { "summon", "earth" },
    class = "mage",
    price = 470,
    repRank = 4,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            fx.summon("character_earth_elemental", fx.tx, fx.ty, {
                scaling = { health = 3, damage = 0.5 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
