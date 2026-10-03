-- SPARED: the lighter heart on a Jackal Weigher's scale (models/envy_oneoffs.lua; "Envy's Bestiary", round 2).
-- No Weigher strikes this body until the next weighing sets another pair down.
--
-- Not a blessing: undispellable, so no strip takes it and the Fairest does not count it.
return {
    name = "Spared",
    abbr = "Lgt",
    description = "Spared: the lighter heart on the scale. No Weigher strikes it.",
    color = { 0.820, 0.800, 0.640 }, -- badge tint (the pan that rises)
    duration = 99, -- a backstop; the next weighing takes it off
    hideDuration = true,
    undispellable = true,
}
