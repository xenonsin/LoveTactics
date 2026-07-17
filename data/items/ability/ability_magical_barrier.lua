-- The arcane ward: lays a Magical Barrier on the caster or a nearby ally, negating magical attacks
-- that land on them. Same shape as ability_physical_barrier -- a support cast at range 2, forging the
-- same `hits` coverage rather than any size -- but single-school: it does nothing against a physical
-- blow. Covering an ally against both takes both wards.
return {
    name = "Magical Barrier",
    description = "Wards yourself or an ally against the next magical blow.",
    flavor = "Single-school, and the Cathedral will not apologise for it. Covering both takes both.",
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
        hits = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 4 }, -- blows the ward swallows, by upgrade level
        effect = function(fx)
            fx.applyStatus(fx.target, "status_magical_barrier", { magnitude = fx.amount })
        end,
    },
}
