-- STARVING: a mouth that found nothing to eat, and comes round sooner for it. Asked for on review
-- (2026-09-23) as "faster, not harder": each stack takes a fifth off the time its next action costs on the
-- timeline (Status.actionTimeScale, compounding), up to three -- about half. Eating anything clears it.
--
-- HOW A MOUTH GOES UNFED is the bearer's question, and there are two answers:
--   * the lion and the goat WAIT -- a turn with nothing to bite or nobody in the cone (Combat.feedHunger,
--     for gear declaring `starves`); any action eats the stacks off.
--   * the serpent always acts, so a coil laid over one still standing is the tell (ability_coil); the bite
--     eats them off (trait_serpents_strike).
--
-- Not a debuff: it is an appetite, not a wound, and a Cure should not make a chimera patient.
return {
    name = "Starving",
    abbr = "Stv",
    description = "Found nothing to eat: its next action takes less time for each stack.",
    color = { 0.690, 0.251, 0.118 }, -- badge tint (ember: the goat's)
    duration = 60,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 3,
    actionTimeScale = 0.8,
    actionTimeScales = true,
}
