-- Defending: a temporary boost to physical defense from taking a defensive stance (the Defend
-- wait-behavior, granted by a shield). Its statBonus is folded into the unit's effective defense
-- via combat's flatStat. It lasts exactly until the unit's NEXT turn: onTurnStart self-expires it
-- (the first turn-start after Defend is the following turn, since Defend itself ends the turn).
-- The `duration` is a generous fallback so it can never get stuck if that turn never comes.
return {
    name = "Defending",
    abbr = "Def",
    description = "Braced: +8 physical defense until this unit's next turn.",
    color = { 0.45, 0.65, 0.85 }, -- badge tint (blue)
    duration = 99,          -- generous fallback; it really ends via onTurnStart (see below)
    hideDuration = true,    -- the fallback countdown is meaningless -- hide it in the tooltip
    statBonus = { defense = 8 },
    onTurnStart = function(ctx) ctx.expire() end,
}
