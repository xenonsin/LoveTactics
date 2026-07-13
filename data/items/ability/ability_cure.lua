-- Cure: the priest cleanses an ally of every debuff at once -- Burn, Wet, Stun, Root, Silenced,
-- Frozen, Mired (any status the blueprint marks `debuff`). Buffs are untouched. Reaches the shared
-- Status.cleanse through fx.cleanse. A support cast (target = "ally" includes the caster), so it reads
-- green. Note an AURA debuff (Mired from standing in quicksand) simply re-applies next step -- Cure
-- frees a unit that has already stepped clear, or buys a turn to move.
return {
    name = "Cure",
    description = "Cleanse an ally of all debuffs.",
    sprite = "assets/items/ability_cure.png",
    type = "ability",
    tags = { "holy", "restorative" },
    class = "priest",
    price = 180,
    repRank = 2,
    activeAbility = {
        name = "Cure",
        target = "ally", -- includes the caster (a unit is its own ally)
        range = 3,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            fx.cleanse(fx.target)
        end,
    },
}
