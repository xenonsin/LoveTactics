-- GROUNDED: the Griffin knocked out of the air, taking every blow whole for two turns. When it wears off
-- the griffin takes wing again with a full three stacks -- the Byrd's cycle, so the window is a thing the
-- company plays for and then has to earn again.
return {
    name = "Grounded",
    abbr = "Gnd",
    description = "Knocked out of the air: takes full damage until it flies again.",
    color = { 0.520, 0.440, 0.330 }, -- badge tint (earth)
    duration = 10, -- two turns at Status.TICKS_PER_TURN
    onExpire = function(ctx)
        if ctx.unit and ctx.unit.alive then
            ctx.applyStatus(ctx.unit, "status_on_the_wing", { magnitude = 3 })
            ctx.log("status", string.format("%s takes wing again.",
                (ctx.unit.char and ctx.unit.char.name) or "It"))
        end
    end,
}
