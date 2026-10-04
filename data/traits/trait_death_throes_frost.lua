-- DEATH THROES: the Frost Worm's (utility_rime_gut; "Sloth's Bestiary", 2026-10-04, slice C). When it dies it
-- bursts, and every body within 2 -- either side -- is Frozen. The counter is the review's own: when it is low,
-- finish it from 3 tiles away.
--
-- onDeath, not onDamaged: the killing blow never reaches onDamaged (trait_volatile argues the same). Frozen's
-- own blueprint carries its delay and its brittleness, so nothing here re-states them.
return {
    name = "Death Throes",
    description = "When you die, you burst: every body within 2 is Frozen.",
    radius = 2,
    notAReaction = true,
    onDeath = function(ctx)
        local u = ctx.unit
        if not u then return end
        ctx.burst(u.x, u.y, { "ice" })
        for _, other in ipairs(ctx.unitsNear(u.x, u.y, ctx.param("radius", 2))) do
            if other ~= u and other.alive then ctx.applyStatus(other, "status_freeze", { applier = u }) end
        end
    end,
}
