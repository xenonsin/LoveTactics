-- WARD OF THE COURT: the Greater Archon's second rule (data/characters/character_greater_archon.lua; "The Crown's
-- Bestiary", slice A, 2026-10-09). When an Archon within 3 of the bearer is struck and still stands, the bearer throws
-- a Magical Barrier over it -- the existing ward, by its own name -- and then waits out a cooldown. It opens every
-- fight under one itself.
--
-- HEARD ON THE STRUCK BODY, NOT HERE. No hook broadcasts a wound to the bodies around it, and every Archon carries
-- Spirit Body, so that trait's onDamaged asks models/archon_court.lua for a ward and the flag below is how the court
-- finds who can throw one. The cooldown is keyed on this trait's id, so the grid slot reads it.
--
-- A MAGICAL barrier, so a sword goes straight through it. That is the review's ward and not an oversight: the court
-- is warded against the company's casters, and the Greater Archon's own beam passes through barriers anyway.
return {
    name = "Ward of the Court",
    description = "When an Archon within 3 is struck, wards it with a Magical Barrier. Opens each fight warded.",
    wardsTheCourt = true,
    reach = 3,
    cooldown = 10, -- ticks: about two turns (Status.TICKS_PER_TURN)
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_magical_barrier", { applier = ctx.unit })
    end,
}
