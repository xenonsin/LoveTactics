-- Root: the unit cannot move on its turn, and at the end of its turn it pays the full movement
-- cost as if it had walked its max distance -- so being rooted still burns time on the timeline.
-- See models/status.lua: blocksMove gates Combat.moveUnit, turnEndMoveCost floors the end-of-turn
-- cost (ctx.moveBudget is the unit's effective movement stat).
return {
    name = "Root",
    abbr = "Rt",
    description = "Cannot move this turn, and still burns time as if it had walked.",
    color = { 0.55, 0.75, 0.45 }, -- badge tint (green)
    duration = 6,                 -- ticks the root lasts
    debuff = true,                -- removable by Cure
    blocksMove = true,
    turnEndMoveCost = function(ctx) return ctx.moveBudget end,
}
