-- Cowering: a body that has stopped moving well because something has frightened it.
--
-- THE STATUS OWNS THE FLINCH; NOTHING OWNS THE REASON. Two things land it today and they have nothing
-- to do with each other: a committed greatsword wind-up (weapon_first_motion) drops it on whoever is
-- standing in the telegraphed footprint, and a wolf's howl (ability_howl) drops it on everyone inside
-- the ring. The first is a blade already coming down; the second is a noise. Both produce the same
-- thing -- feet that no longer go where you want them -- and that sameness is why there is one status
-- here rather than two badges meaning one effect.
--
-- It was written as the greatsword's alone and said so in every line, which is a trap the moment a
-- second deliverer exists: a status that names its own cause is a status that starts lying the first
-- time something else applies it. What a condition IS belongs here; what put it on you belongs to the
-- thing that put it on you.
--
-- A FEAR, NOT A WOUND. It forbids nothing -- you may still swing, cast, answer a blow, hold a post. It
-- only shortens the escape, which is the whole of its counterplay in both mouths: get out from under
-- the blade, or get out of the ring, and find you cannot do it as cleanly as you planned. Against
-- wolves that is the entire point, because the pack's own game is the gap (weapon_wolf_fangs bites and
-- steps away), and this is the pack taking your half of that argument.
--
-- Movement is a flat stat (Combat.moveBudget reads flatStat "movement"), so a plain statBonus does the
-- whole job -- the blue reachable set simply shrinks, exactly as Cripple's does, with no special-case
-- code. A debuff, so Cure strips it.
--
-- THE DURATION IS THE DELIVERER'S. Six ticks is a floor, not a statement: the greatsword overrides it
-- to the length of its own wind-up so the flinch lifts about when the blow lands, and the howl
-- overrides it to ~2 turns so the fear covers the turn you read it on and the turn the pack spends the
-- gap it just bought. Anything landing this should say how long it means.
return {
    name = "Cowering",
    abbr = "Cwr",
    description = "Frightened: moves fewer spaces.",
    color = { 0.657, 0.623, 0.709 }, -- badge tint (wan violet-grey)
    duration = 6,                 -- the floor; every deliverer overrides it on grant (see the header)
    debuff = true,                -- it is done TO a body, so Cure lifts it
    statBonus = { movement = -2 },
}
