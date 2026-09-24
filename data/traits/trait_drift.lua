-- DRIFT: the snowdrift slime's rule (Sloth's slime line) -- it grows by doing nothing (status_drift).
return {
    name = "Drift",
    description = "Each turn it ends where it began: +2 Damage and +2 Defense, up to 5 stacks. Moving sheds them.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_drift", { magnitude = 0 })
    local s = require("models.status").get(ctx.unit, "status_drift")
    if s then s.cap = ctx.param("cap", 5) end
    end,
}
