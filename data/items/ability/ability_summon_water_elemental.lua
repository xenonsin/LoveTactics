-- Bind a water elemental to the field. One of the five elemental summons that join the mage's Fire
-- Elemental (data/items/ability/ability_summon_fire_elemental.lua) -- see it for how `reserve`,
-- `scaling`, `duration` and the one-at-a-time rule work. A sturdy body that leaves foes Wet.
return {
    name = "Summon Water Elemental",
    description = "Binds a water elemental for a time. One at a time; reserves a quarter of your max mana.",
    flavor = "It leaves everything it touches wet, and everything wet is ready for a jolt.",
    sprite = "assets/items/ability_summon_water_elemental.png",
    type = "ability",
    tags = { "summon", "water" },
    class = "mage",
    price = 440,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            fx.summon("character_water_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
