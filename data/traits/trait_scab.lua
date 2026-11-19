-- Scab: a kill heals back the health the bearer paid on this turn (Engine.noteSelfWound keeps the
-- running total as `unit.bledThisTurn`, cleared at turn start). The way back from the edge, and the
-- reason a Blood Price turn ends in a kill rather than in a body on one health.
return {
    name = "Scab",
    description = "A kill heals the health you lost this turn.",
    onKill = function(ctx)
        local owed = ctx.unit.bledThisTurn or 0
        if owed <= 0 then return end
        ctx.unit.bledThisTurn = 0
        ctx.heal(ctx.unit, owed)
    end,
}
