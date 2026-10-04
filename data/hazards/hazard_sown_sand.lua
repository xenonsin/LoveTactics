-- SOWN SAND: the Sandman's Sand in the Eyes (models/sandman.lua; "Sloth's Bestiary", slice G). Laid in a cross, a
-- ring or a row at the end of one of his turns and lifted at the start of the next, when everything standing on it
-- falls Asleep -- on either side. The telegraph is the rule: the sand is on the board a whole turn early.
--
-- It does nothing to a body that crosses it; only standing on it when his turn comes round does. HOSTILE all the
-- same, so every planner reads it as ground to leave, his own side's included.
return {
    name = "Sown Sand",
    description = "Whatever stands here at the start of the Sandman's next turn falls Asleep.",
    tags = { "earth" },
    duration = 9999, -- lifted when it comes due, never by the clock
    disposition = "hostile",
}
