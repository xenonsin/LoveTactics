-- Defending: a temporary boost to physical defense from taking a defensive stance (the Defend
-- wait-behavior, granted by a shield). The bonus is the status's MAGNITUDE, folded into the unit's
-- effective defense via combat's flatStat (see Status.statBonus + `magnitudeStat` below). The
-- granting shield sets how much through its `waitBehavior.defense`, which scales with the shield's
-- upgrade level (Combat.defend passes it as the magnitude); this `magnitude` here is the fallback
-- for a shield that names none. It lasts exactly until the unit's NEXT turn: onTurnStart self-expires
-- it (the first turn-start after Defend is the following turn, since Defend itself ends the turn).
-- The `duration` is a generous fallback so it can never get stuck if that turn never comes.
return {
    name = "Defending",
    abbr = "Def",
    description = "Braced: raised physical defense until this unit's next turn.",
    color = { 0.45, 0.65, 0.85 }, -- badge tint (blue)
    duration = 99,          -- generous fallback; it really ends via onTurnStart (see below)
    hideDuration = true,    -- the fallback countdown is meaningless -- hide it in the tooltip
    magnitude = 8,          -- default +defense when the granting shield sets no waitBehavior.defense
    magnitudeStat = "defense", -- the flat stat this status's magnitude raises (via Status.statBonus)
    onTurnStart = function(ctx) ctx.expire() end,
}
