-- HUNTS BY EAR: the Sewn-Eyed Penitents' (data/items/utility/utility_sewn_eyes.lua; "Envy's Bestiary", 2026-10-03,
-- slice C). From Dante's terrace of the envious, whose eyes are sewn shut with iron wire. Blind, they hunt by
-- sound: the last of the company to finish a turn is the one they strike (AI.preempt -> models/envy_seat.lua).
--
-- Heard here, on every foe's turn end, and kept on the penitent (`unit.lastFoeToAct`). Invisible is no cover and
-- an illusion is never heard, since only a body that takes a turn makes a sound; the organ carrying this also
-- carries the immunity to Blind.
return {
    name = "Hunts by Ear",
    description = "Strikes the last foe to act. Invisible foes and illusions do not fool it.",
    huntsByEar = true,
    notAReaction = true,
    onAnyTurnEnd = function(ctx)
        local actor, u = ctx.actor, ctx.unit
        if actor and u and actor.side ~= u.side and not actor.decoyOf then u.lastFoeToAct = actor end
    end,
}
