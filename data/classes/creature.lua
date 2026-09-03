-- Creature -- the ROOT class for kit that belongs to no job.
--
-- A wolf's bite, a demon's brimstone, the sigil that drives a boss's phase machinery: none of it was
-- made by a house, none of it is sold, and most of it is `noSteal` so it never reaches a player's grid
-- at all. Before the fold those items simply had no `class`, which was honest as long as `class` meant
-- "sold by" -- an unpriced thing sits on no shelf, so it named no shelf.
--
-- IT CANNOT STAY BARE once class is the only taxonomy. Every reading that used to fall back on the
-- absent field -- what does a use tally, what does the forge charge, what does the tooltip print --
-- has to answer something, and "nil" is an answer that has to be special-cased at each of them
-- separately. One root says it once: this belongs to no job, and here is the job that means.
--
-- NOT PLAYABLE, and that is the field doing real work. A root is otherwise something every body holds
-- from the first morning and can climb; this one is never offered, never announced, stocks nothing, and
-- is skipped by every spec that asks a class to behave like a career. It is a bucket with a name, not a
-- job -- which is exactly what the items in it are.
return {
    name    = "Creature",
    description = "Not a job. The kit that belongs to no house -- natural weapons, a demon's own art, "
        .. "and the machinery a boss runs its phases on. Never sold, never taught, mostly never carried.",
    playable = false, -- never offered as a career: no exemplar, no shelf, no gate
}
