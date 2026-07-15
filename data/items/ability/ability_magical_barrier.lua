-- The arcane ward: lays a Magical Barrier on the caster or a nearby ally, negating the next magical
-- attack that lands on them. Same shape as ability_physical_barrier -- a support cast at range 2 --
-- but single-school: it does nothing against a physical blow. Covering an ally against both takes
-- both wards.
return {
    name = "Magical Barrier",
    description = "Ward yourself or an ally against the next magical blow.",
    sprite = "assets/items/ability_magical_barrier.png",
    type = "ability",
    tags = { "holy", "protective" },
    class = "priest",
    price = 160,
    repRank = 2,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            fx.applyStatus(fx.target, "magical_barrier")
        end,
    },
}
