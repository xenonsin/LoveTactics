-- KINDLING: Wrath's rule, one rank down, and the mechanic the volcanic circle is built on.
--
-- Ira's Rising Wrath sharpens with every blow she takes AND worse the nearer she is to death -- a flat
-- +1 per contact plus up to +20 scaled by missing health (data/traits/trait_wrath_rising.lua). Two terms
-- compounding, uncapped, which is correct for the thing at the bottom of a circle and unreadable as a
-- first encounter: a player watching their damage stop working cannot tell which of the two is doing it.
--
-- So this is one term, capped. Blows taken only -- no missing-health curve at all -- and it stops
-- climbing at CEILING. What that buys is legibility: the number goes up a little every time you hit it,
-- visibly, and then stops. Then you take the stair and meet the thing where it never stops and gets
-- worse as it dies.
--
-- THE CAP IS THE WHOLE DIFFERENCE, so it is a named constant rather than an inline number. A mini sin's
-- second phase is its general's first, and here the phase is simply removing this
-- (data/items/utility/utility_cold_forge.lua).
return {
    name = "Kindling",
    description = "Sharpens with every blow it takes, up to a limit.",
    perBlow = 2,
    ceiling = 12, -- and it stops here, which is the only thing separating it from Ira
    onDamaged = function(ctx)
        ctx.trait.stacks = (ctx.trait.stacks or 0) + 1
        local want = math.min(ctx.def.ceiling, ctx.def.perBlow * ctx.trait.stacks)
        local have = ctx.trait.applied or 0
        if want <= have then return end
        ctx.addBonus("damage", want - have)
        ctx.trait.applied = want
        ctx.applyStatus(ctx.unit, "status_wrath", { magnitude = want })
    end,
}
