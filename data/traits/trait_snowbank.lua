-- SNOWBANK's rule (data/items/utility/utility_snowbank.lua): Drift's Defense half, worn.
return {
    name = "Snowbank",
    description = "Each turn you end where you began: +2 Defense, up to +6. Moving resets it.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_snowbank", { magnitude = 0 })
    local s = require("models.status").get(ctx.unit, "status_snowbank")
    if s then s.cap = ctx.param("cap", 3) end
    end,
}
