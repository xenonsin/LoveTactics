-- Stun: shoves the target down the turn order by adding ticks to its initiative. The shove is
-- applied once, on cast (onApply); `duration` keeps the "Stunned" badge on the body for as long as
-- the delay it bought is still being served. See models/status.lua for the hook contract.
--
-- THE BADGE IS BOUNDED AT BOTH ENDS, and the two ends are written in different places because they
-- fail in opposite directions:
--
--   * The FLOOR is in Status.apply ("A BADGE MUST OUTLAST THE DELAY IT CAUSES"): a stun handed a
--     magnitude by its caster -- Jolt shoves 10, Thunder Storm shoves its damage -- would otherwise
--     shove the target further down the order than a 5-tick badge lasts, and expire having done
--     nothing anyone could see or exploit.
--   * The CEILING is onTurnStart, here. A unit sits at initiative 0 the moment its turn opens, which
--     is the same statement as "the shove has been served in full" -- there is nothing left of a stun
--     at that point, since the whole of it is the delay and the reactions the delay costs. Without
--     this the stretched badge outlives its own shove by `duration` (a Jolt shoves 10 and badges 15),
--     so the target takes a whole turn wearing "Stunned" and the status reads as broken to anybody
--     watching the board.
--
-- Frozen deliberately does NOT do this: its badge is a brittleness window that is meant to outlast
-- the delay, so a hammer can shatter a body the ice has already finished delaying (see its `duration`
-- note). Stun has no such second half, which is what makes the ceiling right here and wrong there.
return {
    name = "Stun",
    abbr = "St",
    description = "Shoved down the turn order, delaying the target's next turn.",
    color = { 0.862, 0.783, 0.383 }, -- badge tint (gold)
    magnitude = 5,                -- ticks added to the target's initiative
    shovesInitiative = "magnitude", -- the delay the aim preview quotes (Status.initiativeShove); == onApply's shove
    duration = 5,                 -- ticks the badge lingers (stretched to cover a bigger shove, above)
    debuff = true,                -- removable by Cure
    interruptsChannel = true,     -- a stunned caster drops whatever spell it was channeling
    disablesReactions = true,     -- a stunned unit is too rattled to counter, dodge or otherwise react
    onApply = function(ctx)
        ctx.unit.initiative = ctx.unit.initiative + (ctx.magnitude or 0)
    end,
    -- The delay has been served: the body is back at initiative 0 and standing up. See above.
    onTurnStart = function(ctx) ctx.expire() end,
}
