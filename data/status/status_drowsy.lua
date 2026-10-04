-- DROWSY: the cold's sleep creeping up on a body that stands still ("Sloth's Bestiary", 2026-10-04). Laid by
-- Yuki-onna's Snow-Sleep (within 3 of her), Desidia's Drowse (the whole board) and the White Silence drop.
--
-- AT 3 IT FALLS ASLEEP: the stack is spent and Sleep goes on in its place, so the answer to it is Sleep's own --
-- hit it, or Cure it. A stack lasts three turns, refreshed by every new one, so a body that starts moving again
-- shakes it off rather than carrying it to the end of the fight.
return {
    name = "Drowsy",
    abbr = "Drow",
    description = "Drowsy: at 3, falls Asleep.",
    color = { 0.600, 0.660, 0.820 }, -- badge tint (snow-light blue)
    duration = 15, -- three turns at Status.TICKS_PER_TURN
    debuff = true,
    magnitude = 1,
    stacks = 3,
    onApply = function(ctx)
        if (ctx.status.magnitude or 0) < 3 then return end
        ctx.expire()
        ctx.applyStatus(ctx.unit, "status_sleep", { applier = ctx.applier })
    end,
}
