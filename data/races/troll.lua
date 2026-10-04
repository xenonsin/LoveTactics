-- Troll: the folk under the meltwater bridges of Sloth's approach. Reviewed 2026-10-04 ("Sloth's Bestiary",
-- round 1: the race rule Indifferent approved as pitched).
--
-- INDIFFERENT IS THE WHOLE RACE. A troll does not bother to get out of the way -- it never dodges -- and does not
-- need to: at the top of each of its turns it regrows a fifth of its health, unless fire or acid has reached it
-- since its last. So the company's lever is ORDER, not size: burn it first, then hit it, or put it down inside a
-- single turn. A wound the troll is given time to sleep on was never dealt.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 slash, +1 impact, -2 pierce): a hide like a boot sole turns an edge and
-- takes a club, and a spear goes through it. The fire line is the rule's own and is kept small (-2) because the
-- regrowth is what fire is really answering.
--
-- THE STAT LINE is a body built to soak (defense +1) and to hit back (damage +1). Within the budget of 2.
--
-- INDIFFERENT IS GRANTED rather than authored into every grid (utility_troll_blood), bound and unstealable.
--
-- NOT PLAYABLE: the trolls are the approach's traffic, never the company's.
return {
    name = "Troll",
    description = "Hulking folk of the meltwater bridges. They never dodge, and every wound regrows unless it burned.",
    kind = "humanoid",
    playable = false,
    resist = {
        slash = 1,   -- a hide like a boot sole turns an edge...
        impact = 1,  -- ...and takes a club...
        pierce = -2, -- ...and a spear goes straight through. Sums to zero.
        fire = -2,   -- the regrowth's own answer, kept small: the rule is what fire really beats
    },
    bonus = {
        defense = 1, -- built to soak...
        damage = 1,  -- ...and to hit back
    },
    grants = { "utility_troll_blood" },
}
