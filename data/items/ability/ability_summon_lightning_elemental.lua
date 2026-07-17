-- Bind a lightning elemental to the field. See ability_summon_fire_elemental.lua for how the
-- reservation, scaling, duration and one-at-a-time rule work. A frail but hard-hitting glass cannon.
return {
    name = "Summon Lightning Elemental",
    description = "Binds a lightning elemental for a time. One at a time; reserves a quarter of your max mana.",
    flavor = "A glass cannon with a temper. It will not be alive long enough to regret it.",
    sprite = "assets/items/ability_summon_lightning_elemental.png",
    type = "ability",
    tags = { "summon", "lightning" },
    class = "mage",
    price = 460,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            fx.summon("character_lightning_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
