-- THE WEIGHING: the Jackal Weighers' rule, on their organ (data/items/utility/utility_the_weighing.lua). Reviewed
-- 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- At the start of its turn a Weigher sets two of the company on the scale -- the two nearest it -- and the badges
-- show which is which: the lighter heart (less current health) is Spared, the heavier is Weighed and every
-- Weigher strikes it (`weighsHearts`, read by models/envy_oneoffs.lua's planner). The weighing itself rides the
-- Weigher's badge (status_weighing), because only a status hears its turn start.
return {
    name = "The Weighing",
    description = "Each turn, weighs two foes: the one with less health is Spared, and every Weigher strikes the other.",
    weighsHearts = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u and u.alive then ctx.applyStatus(u, "status_weighing", { applier = u }) end
    end,
}
