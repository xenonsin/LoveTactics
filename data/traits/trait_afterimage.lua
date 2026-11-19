-- Afterimage: every QUICK action (speed 2 or less) leaves a little barrier behind (models/engine.lua's
-- pooled barrier). Defence made out of offence, which is the fighter's Tempo engine paying in something
-- other than damage: a body jabbing in place is a body raising its guard.
return {
    name = "Afterimage",
    description = "Each action of speed 2 or less grants 2 barrier.",
    magnitude = 2,
    onCast = function(ctx)
        local Engine = require("models.engine")
        if (ctx.speed or 99) > Engine.QUICK_SPEED then return end
        local amount = ctx.param("barrier", ctx.def.magnitude or 2)
        Engine.grantBarrier(ctx.combat, ctx.unit, amount)
    end,
}
