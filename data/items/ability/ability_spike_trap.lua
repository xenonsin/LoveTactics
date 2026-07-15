-- An ability that lets its bearer summon a hidden spike trap on a nearby tile. Uses the tile-target
-- ability kind (target = "tile"): Combat.useItem allows any in-range cell and hands the clicked
-- coordinates to the effect as fx.tx / fx.ty, which fx.placeTrap turns into an owned trap.
return {
    name = "Spike Trap",
    description = "Summon a hidden spike trap on a nearby tile.",
    sprite = "assets/items/ability_spike_trap.png",
    type = "ability",
    tags = { "trap", "utility" },
    class = "rogue",
    price = 330,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            -- The forged trap bites harder: base 18 damage, +1 per upgrade level.
            fx.placeTrap(fx.tx, fx.ty, "spike_trap", { amount = 18 + fx.level })
        end,
    },
}
