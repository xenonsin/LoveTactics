-- Shattered Leg: the movement half of the injury of the same name (data/injuries/injury_shattered_leg.lua).
--
-- WHY THIS IS NOT JUST CRIPPLE, which is the same subtraction for a different reason and which this
-- system reused for exactly that argument until 2026-09-22. Two reasons, and the first is a bug:
--
--   * CRIPPLE IS `debuff = true`, and Status.cleanse strips every debuff a body is wearing. So one Cure
--     lifted a broken leg for the rest of the fight -- the campaign's whole attrition meter, undone by
--     a 1-rung ability, and neither the item nor the meter knew it was happening. An injury is not a
--     thing a spell answers; it is a thing the Ward answers. `debuff = false` closes it, and closes it
--     at the only door (Status.cleanse's filter) rather than by special-casing this id in six places.
--   * A PERMANENT CONDITION AND A TWO-TURN DEBUFF MUST NOT READ THE SAME. A player who sees Crp on a
--     body has learned to wait it out. This one does not run out, and a badge that says otherwise is
--     teaching the wrong thing at the moment it matters -- which is why it carries its own name rather
--     than the catalogue's.
--
-- The MAGNITUDE is still Cripple's, because the board has been balanced against exactly this much
-- missing movement and there is no reason to invent a second figure for the same disability.
--
-- `statBonus` rides Status.statBonus into Combat.flatStat("movement"), so the blue reachable set simply
-- shrinks -- no special-case reader, the same free ride Cripple has always had. A second Shattered Leg
-- stacks, and what stops it reaching zero is the floor Injury.combatEffects clamps against (never below
-- a quarter of the body's own base), handed in as a per-instance `statBonus` so the badge shows what
-- was actually taken rather than what was authored.
return {
    name = "Shattered Leg",
    abbr = "Leg",
    description = "Shattered Leg: moves fewer spaces each turn.",
    color = { 0.642, 0.430, 0.234 }, -- badge tint (rust)
    duration = 9999,             -- a condition the body arrived with; only the Ward ends it
    debuff = false,              -- see above: no Cure lifts an injury
    statBonus = { movement = -2 },
}
