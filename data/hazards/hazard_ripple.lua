-- RIPPLE: where Leviathan will rise (models/leviathan.lua). Laid over a 3x3 at the end of one of its turns and
-- lifted at the start of the next, when the sand under it erupts -- the telegraph the review asked for ("a ripple
-- in the sand shows where it moves"), on the board a turn early like a wind-up's ghost.
--
-- It does nothing to a body standing in it. HOSTILE all the same, so every planner reads it as ground to leave:
-- that is the whole of what it is for. The Undertow, the drop, is a wind-up and needs none -- its channel's own
-- ghost is the same promise.
return {
    name = "Ripple",
    description = "Leviathan rises here at the start of its next turn.",
    tags = { "earth" },
    duration = 9999, -- lifted by the eruption, never by the clock
    disposition = "hostile",
}
