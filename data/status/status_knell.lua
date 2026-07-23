-- Knell: an hour named for somebody else. When the count runs out the unit dies -- whatever its health,
-- whatever its armor, whoever it is. The only status in the game that kills by arithmetic instead of by
-- damage over time, and the design is almost entirely about making that fair to look at.
--
-- THE KILL FIRES FROM onTick, NOT onExpire, and that is load-bearing rather than stylistic. Status.remove
-- and Status.cleanse both run a def's `onExpire` on EVERY removal path (models/status.lua) -- so a Knell
-- that killed from there would kill the moment a priest Cured it, which is the exact opposite of what a
-- Cure is for. onTick runs BEFORE Status.tick decrements `remaining`, so the hook can see the tick that
-- would take the count to zero and toll on it, while a cleanse simply lifts the status and nothing fires.
-- Curing it is a clean save; letting it run is a death. Nothing in between.
--
-- WHY THE COUNT IS PLAIN `duration` and not a private counter. It could have been one -- and then the
-- badge would have had to read 9999 while a separate number nobody could see did the actual counting.
-- A death sentence whose clock is invisible is not tension, it is a rug pull: the whole tactical content
-- here is the party looking at a number, counting turns, and deciding whether the cure is worth a turn
-- they wanted to spend killing something. So the count IS the duration, the badge wears the hourglass
-- like every other duration in the UI, and what you see is what will happen.
--
-- DELIBERATELY NOT `resistible`. The resist system buys DURATION against a warded body (Status.RESIST_SOFT
-- and the diminishing-returns halving) -- which here would mean a high-magicDefense target's sentence
-- comes due SOONER, and a second Knell on the same body kills FASTER than the first. The lever is
-- backwards for a countdown, so the countdown does not use it. That leaves exactly one counterplay and it
-- is a good one: `debuff = true`, so Cure, Panacea and any dispel take it off entirely.
--
-- `lingers`, so it travels with its host. There is no ground to step off; the appointment is with the
-- person.
return {
    name = "Knell",
    abbr = "Knl",
    description = "Marked for an hour: when the count runs out, this unit dies.",
    color = { 0.55, 0.20, 0.28 }, -- badge tint (a deep funeral red, unlike anything else on the strip)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN: long enough to cure, short enough to fear
    debuff = true, -- the whole counterplay: Cure and Panacea lift it
    lingers = true, -- the appointment is with the person, not the tile
    -- Suppressed because this file writes its own, better line below. Without it the tick loop would
    -- announce "X's Knell wears off" a beat AFTER the toll killed X, which reads as a reprieve.
    hideLog = true,
    onTick = function(ctx)
        local s = ctx.status
        -- Not yet. `remaining` has not been decremented for this slice at the point onTick runs, so this
        -- is the tick on which the count would reach zero -- and the last chance anything had to cure it
        -- has already passed.
        if (s.remaining - (ctx.elapsed or 0)) > 0 then return end

        local hp = ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.health
        local left = (hp and hp.current) or 0
        if left <= 0 then return end
        ctx.log("status", string.format("%s's hour comes.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"), ctx.unit)
        -- Raw, so no armor and no tag resist gets a say -- the toll is not a blow being blocked. Routed
        -- through ctx.damage rather than a direct kill so it goes down the ordinary death path: a corpse
        -- is left, death reactions fire, and a Second Wind still gets to refuse it. That last one is a
        -- real interaction and it is the right answer -- "one refusal to fall" is precisely the thing
        -- that ought to answer a named hour.
        ctx.damage(ctx.unit, left, { "dark" }, { raw = true })
    end,
}
