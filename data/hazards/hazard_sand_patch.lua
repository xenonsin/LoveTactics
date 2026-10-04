-- SAND PATCH: the tile the Sandman ran out of (Run Through the Glass, models/sandman.lua; "Sloth's Bestiary",
-- slice G), and the tile an Hourglass's bearer left. Whoever ENDS A TURN on it falls Asleep, either side.
--
-- Crossing it costs nothing, which is why the effect is not an onEnter: the sleep is read off where a body stops,
-- by the trait that laid it (trait_run_through_the_glass's onAnyTurnEnd). Hostile, so a planner does not stop here.
return {
    name = "Sand Patch",
    description = "Whoever ends a turn here falls Asleep.",
    tags = { "earth" },
    duration = 9999, -- the rest of the fight
    disposition = "hostile",
}
