-- A protective ward: lays a Physical Barrier on the caster or a nearby ally, negating physical attacks
-- that land on them. A support cast (target = "ally" includes the caster), so it reads green and the
-- AI treats it as friendly. The barrier itself times out if no blow comes -- see
-- data/status/physical_barrier.lua.
--
-- `hits` is what forging this spell buys: how many blows the ward it lays will swallow before it is
-- spent. It is the ability's magnitude (Combat.abilityMagnitude reads it, so it arrives as fx.amount
-- and heads the tooltip), for want of any other -- a negation has no size to grow, only a count. The
-- curve is deliberately flat and slow: each step is a whole extra blow erased, which is worth far more
-- than a few points of damage, so a barrier that gained one per level would end the game erasing an
-- entire round of focused fire.
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
        target = "ally", -- includes the caster (a unit is its own ally)
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 12 },
        hits = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 4 }, -- blows the ward swallows, by upgrade level
        effect = function(fx)
            fx.applyStatus(fx.target, "physical_barrier", { magnitude = fx.amount })
        end,
    },
}
