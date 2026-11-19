-- Reaper's Stride: two free steps (the hunter's Reaper's Ledger). +2 movement until the end of the
-- bearer's next turn -- the kill pays for the walk to the next one. Granted by the Ledger's trait when
-- a weapon beside it lands a killing blow (data/traits/trait_reapers_ledger.lua).
return {
    name = "Reaper's Stride",
    abbr = "Str",
    description = "Reaper's Stride: +2 movement until the end of its next turn.",
    color = { 0.72, 0.80, 0.52 }, -- badge tint (hunter green)
    duration = 15,
    statBonus = { movement = 2 },
    -- Granted mid-turn by the kill, so the turn it lands in is not the one it is for: it arms at the
    -- bearer's next turn start and goes at that turn's end.
    onTurnStart = function(ctx) ctx.status.armed = true end,
    onTurnEnd = function(ctx) if ctx.status.armed then ctx.expire() end end,
}
