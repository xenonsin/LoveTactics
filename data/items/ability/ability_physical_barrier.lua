-- A protective ward: lays a Physical Barrier on the caster or a nearby ally, negating the next
-- physical attack that lands on them. A support cast (target = "ally" includes the caster), so it
-- reads green and the AI treats it as friendly. The barrier itself times out if no blow comes --
-- see data/status/physical_barrier.lua.
return {
    name = "Physical Barrier",
    description = "Ward yourself or an ally against the next physical blow.",
    sprite = "assets/items/ability_physical_barrier.png",
    type = "ability",
    tags = { "holy", "protective" },
    class = "priest",
    price = 160,
    repRank = 2,
    activeAbility = {
        name = "Physical Barrier",
        target = "ally", -- includes the caster (a unit is its own ally)
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            fx.applyStatus(fx.target, "physical_barrier")
        end,
    },
}
