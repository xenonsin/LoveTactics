-- STILLWATER's rule (data/items/utility/utility_stillwater.lua).
return {
    name = "Stillwater",
    description = "+3 Defense after a turn you didn't move.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_stillwater", { magnitude = 0 })
    end,
}
