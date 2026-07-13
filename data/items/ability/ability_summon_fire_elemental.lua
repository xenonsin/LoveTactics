-- Bind a fire elemental to the field. The mage's counterpart to Summon Wolf: the same reservation
-- bargain (a quarter of maximum mana, spent on the cast and locked away for as long as the elemental
-- stands), placed at arm's length rather than adjacent, and scaling its magicDamage rather than its bite.
-- See data/items/ability/ability_summon_wolf.lua for how `reserve` and `scaling` work -- including the
-- one-at-a-time rule: the binding cannot be renewed while the elemental it made still stands.
--
-- Where the wolf differs: this one is BOUND, not called, and a binding lapses. `duration` gives the
-- elemental 24 ticks (roughly four rounds) before it fades of its own accord -- which also returns the
-- reserved mana and frees the ability. So the mage's summon is a burst of pressure on a timer, while
-- the archer's wolf is a permanent body that only mana scarcity limits. Cast it early and it will be
-- gone by the endgame; hold it and you are down a quarter of your mana until you spend it.
return {
    name = "Summon Fire Elemental",
    description = "Bind a fire elemental to the field for a time, one at a time. Reserves a quarter of your maximum mana while it lives.",
    sprite = "assets/items/ability_summon_fire_elemental.png",
    type = "ability",
    tags = { "summon", "fire" },
    activeAbility = {
        name = "Summon Fire Elemental",
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        power = { 12, 13, 14, 16, 17, 18, 19, 20, 22, 23, 24 },
        effect = function(fx)
            fx.summon("fire_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                power = fx.power,
                duration = 24, -- ticks; the binding lapses and the elemental fades
            })
        end,
    },
}
