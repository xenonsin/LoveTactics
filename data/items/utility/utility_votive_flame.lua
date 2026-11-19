-- Votive Flame: the Theurge's Overflow payoff (docs/engines.md). When a channelled working resolves, the
-- bearer's Radiance is spent as wind-up the theurge did not have to sit through (trait_votive_flame): The
-- Long Prayer lays wider ground, as though the prayer had been held longer. It banks Radiance itself, so
-- a theurge healing past full fills it without a Reliquary.
return {
    name = "Votive Flame",
    description = "When your channel resolves, consume all Radiance: it counts 1 more tick held per 2 Radiance.",
    flavor = "Lit at the first word of the prayer. It is expected to last the whole of it.",
    sprite = "assets/items/utility_votive_flame.png",
    type = "utility",
    tags = { "holy" },
    class = "theurge",
    unlockLevel = 6,
    charge = { key = "radiance", from = { "overheal" }, max = 20 },
    traits = { "trait_votive_flame" },
    bonus = { magicDefense = 1 },
}
