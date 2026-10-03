-- DOPPEL-STEP: the badge that owns a Doppel-Step shape (data/items/ability/ability_doppel_step.lua), the way Wolf
-- Shape owns a wolf. The cast wears the copy; this ends it.
--
-- "UNTIL THE END OF YOUR NEXT TURN" is counted in turn-ends, not ticks: the turn it was cast in ends once, the next
-- one ends twice, and the second takes it off. The duration is only a fallback so it can never stick.
--
-- An illusion, like every worn shape: Dispel Illusions ends it early. onExpire is the one reversion point.
return {
    name = "Doppel-Step",
    abbr = "Dopl",
    description = "Wearing an exact copy of another body until the end of your next turn.",
    color = { 0.620, 0.660, 0.640 }, -- badge tint (the Faceless grey)
    duration = 99,
    hideDuration = true,
    illusion = true,
    onTurnEnd = function(ctx)
        local s = ctx.status
        s.ends = (s.ends or 0) + 1
        if s.ends >= 2 then ctx.expire() end
    end,
    onExpire = function(ctx)
        ctx.revert()
    end,
}
