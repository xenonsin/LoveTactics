-- SURFACED: the bearer just came up out of the floor -- a Delve, Through the Rock -- and its next blow
-- lands as a critical (Combat.forcesCrit's "up from below" clause; the landing spends it in
-- Combat.dealDamage). Stamped only on a body carrying the Deep-Delver's Pick (trait_deep_delver), so a
-- dwarf line that delves all fight does not wear a badge that means nothing on it.
return {
    name = "Surfaced",
    abbr = "Up",
    description = "Surfaced: the next blow lands as a critical.",
    color = { 0.470, 0.390, 0.300 }, -- badge tint (turned earth, as Underground)
    duration = 10, -- the rest of this turn and the next: a surfacing is a moment, not a stance
}
