-- Root: the unit cannot move on its turn, nobody else may move it either, and at the end of its turn
-- it pays the full movement cost as if it had walked its max distance -- so being rooted still burns
-- time on the timeline. See models/status.lua: blocksMove gates Combat.moveUnit, blocksForcedMove
-- gates every shove and drag, turnEndMoveCost floors the end-of-turn cost (ctx.moveBudget is the
-- unit's effective movement stat).
--
-- WHY THE PIN CUTS BOTH WAYS. A snare that stopped a body walking but let a mace throw it across the
-- lane is saying two things about the same pair of feet, and the second one wins -- rooting a target
-- would be step one of moving it wherever you liked, since the shove no longer has to beat any
-- movement the victim could spend answering it. Read as a bargain it is the one thing a debuff this
-- flat has to offer: you lose the turn and gain the ground, and a rooted knight in a doorway is still
-- in the doorway. The blow that carried the shove still lands in full -- what is refused is the
-- displacement, not the attack (Combat.knockback), and with no travel there is no impact to take.
return {
    name = "Root",
    abbr = "Rt",
    description = "Cannot move this turn and cannot be moved, and still burns time as if it had walked.",
    color = { 0.543, 0.710, 0.460 }, -- badge tint (green)
    duration = 6,                 -- ticks the root lasts
    debuff = true,                -- removable by Cure
    blocksMove = true,
    blocksForcedMove = true,      -- and no shove, throw, drag or charge budges it either
    turnEndMoveCost = function(ctx) return ctx.moveBudget end,
}
