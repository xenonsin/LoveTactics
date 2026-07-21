-- Sleep: the target is put under, and comes back around far later than it meant to. Like Stun (whose
-- shape this borrows), the effect is a shove DOWN THE TURN ORDER -- this game models "you lose your
-- turn" as initiative, not as a skipped slot, so a sleep is a stun that lasts far longer and is far
-- easier to undo.
--
-- IT BREAKS ON DAMAGE, which is the entire design and the reason it isn't simply a better Stun. Any hit
-- at all wakes the sleeper and HANDS BACK the time it hadn't yet served. So Sleep is not a setup for
-- focused fire; it is the opposite of one. It says "this half of the board is not part of the fight for
-- a while", and it holds only as long as you leave it alone. Sleep the flank, kill the middle.
--
-- That makes the counterplay free, universal, and available by accident: a stray arrow, a Fireball that
-- clips the sleeper, a Burn already ticking on them. It is the rare hard-control effect whose answer is
-- "hit it" -- the one answer every character in the game has. A player who sleeps a unit and then
-- splashes it has wasted the spell and learned the rule in the same beat.
--
-- THE ONE NUMBER. The shove, the badge, and the refund are all `remaining`, deliberately -- there is no
-- separate `magnitude` here (compare Stun, which has both). Reading the shove off the instance's own
-- remaining ticks is what makes resistance work on this status at all: Status.apply hands the instance
-- an already-shortened duration (see the resistance contract in models/status.lua), so a warded target
-- is shoved by exactly as much as it is asleep for. A `magnitude` would have been a second number that
-- resistance never touched -- a fully-resisted sleep with a 2-tick badge and a 14-tick shove, which is
-- not a shorter sleep, it is a bug wearing one.
--
-- The bookkeeping rule that falls out of it: on ANY removal, give back the ticks not yet served
-- (`remaining`), capped at what was actually taken. A natural countdown has nothing left to give back
-- -- remaining has reached 0 and the sleeper genuinely waited -- so it refunds nothing and needs no
-- special case. A Cure at 3 ticks left refunds 3. A blow at 3 ticks left refunds 3. One rule, and
-- every ending is the same ending.
return {
    name = "Sleep",
    abbr = "Slp",
    description = "Asleep: pushed far down the turn order, until something wakes it.",
    color = { 0.55, 0.60, 0.85 }, -- badge tint (dusk blue)
    duration = 14,                -- the shove, the badge, and the refund cap: see "THE ONE NUMBER"
    shovesInitiative = "duration", -- so the aim preview reads the shove off the SAME (resisted) remaining onApply does
    debuff = true,                -- Cure/Panacea rouse it early
    resistible = "magical",       -- warded by magicDefense + statusResist, halved on every repeat
    interruptsChannel = true,     -- a sleeper is not finishing the spell it was winding up
    disablesReactions = true,     -- and it is not countering, parrying, or dodging anything either
    onApply = function(ctx)
        -- Shove ONCE. Status.apply re-runs onApply on a refresh, and a sleep that shoved again on
        -- every recast would be an unbounded initiative lock -- exactly what the diminishing-returns
        -- curve exists to make impossible. `slept` also records what was taken, so no ending can
        -- refund more than the spell ever cost (a refresh extends the badge past the original shove).
        if ctx.status.slept then return end
        local shove = math.max(0, ctx.status.remaining or 0)
        ctx.status.slept = shove
        ctx.unit.initiative = ctx.unit.initiative + shove
    end,
    onDamaged = function(ctx)
        -- Woken. The refund itself is onExpire's job -- ctx.expire routes through Status.remove, which
        -- fires it on the way out -- so a blow and a Cure settle the debt through the same line.
        if not ctx.status.slept then return end
        ctx.log("status", string.format("%s is jolted awake!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.expire()
    end,
    onExpire = function(ctx)
        -- Fires on EVERY removal path (countdown, damage, Cure, dispel). Give back the ticks the
        -- sleeper never served, never more than were taken. A natural countdown lands here with
        -- remaining <= 0 and correctly refunds nothing.
        local taken = ctx.status.slept
        if not taken then return end
        ctx.status.slept = nil
        local unserved = math.min(taken, math.max(0, ctx.status.remaining or 0))
        if unserved > 0 then ctx.unit.initiative = ctx.unit.initiative - unserved end
    end,
}
