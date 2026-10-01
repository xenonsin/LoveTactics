-- RIDDLE: STILLNESS -- one of the five riddles a Sphinx asks (models/pride_elites.lua's RIDDLES; "Pride's
-- Bestiary", 2026-09-30). Met when no body of the asked side ends a turn off the tile it began it on. A shove
-- on the asker's own turn is not a step the company took, so it does not count against them.
return {
    name = "Riddle: Stillness",
    abbr = "?Sti",
    description = "Riddle: none of you moves before its next turn.",
    color = { 0.780, 0.650, 0.380 }, -- badge tint (sandstone, the five riddles alike)
    duration = math.huge,
    hideDuration = true,
    hideLog = true, -- the asking is logged by the riddle itself, in a sentence
}
