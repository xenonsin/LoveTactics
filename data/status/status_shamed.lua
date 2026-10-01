-- SHAMED: a djinn that was cornered (models/djinn.lua, Will Not Stoop). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- It lands at the top of the djinn's turn and takes that turn: no act and no move, so all that is left is to
-- wait. It ends when the turn does. A price the djinn pays for its own pride rather than a thing done to it, so
-- it is not a debuff, and no Cure lifts it.
--
-- THE TURN IS LOST, NOT SHOVED. Stun and Spent take a turn by pushing the next one down the order; this lands on
-- the turn already open, so it refuses the act (Halted's `disablesActions`) and the walk (`blocksMove`) instead.
return {
    name = "Shamed",
    abbr = "Shmd",
    description = "Shamed: cannot act or move this turn.",
    color = { 0.620, 0.420, 0.560 }, -- badge tint (a flush)
    duration = 5,
    hideDuration = true, -- it ends with the turn, not on the clock
    disablesActions = true,
    blocksMove = true,
    onTurnEnd = function(ctx) ctx.expire() end,
}
