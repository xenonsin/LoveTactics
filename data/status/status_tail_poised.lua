-- POISED TAIL: a serpent head coiled on the body it grows from (ability_coil). While it stands, the first
-- foe to strike that body in melee is bitten and Poisoned, which spends it (trait_serpents_strike, on the
-- item that grew the head). Re-laid by every coil, so it lasts exactly as long as the serpent keeps coming
-- round -- the duration is a ceiling, not the clock.
--
-- Not a debuff: it is the body's own readiness, and a Cure must not be the answer to it. The answer is
-- letting the right body go in first, or breaking the serpent.
return {
    name = "Poised Tail",
    abbr = "Tail",
    description = "The first foe to strike this body in melee is bitten and poisoned.",
    color = { 0.184, 0.420, 0.369 }, -- badge tint (verdigris: the serpent's)
    duration = 40,
    hideDuration = true,
}
