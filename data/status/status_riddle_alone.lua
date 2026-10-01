-- RIDDLE: ALONE -- one of the five riddles a Sphinx asks (models/pride_elites.lua's RIDDLES; "Pride's Bestiary",
-- 2026-09-30). Met when exactly one body of the asked side makes a strike -- any cast that deals damage, at
-- anything -- before the asker's next turn. Nobody striking is not an answer.
return {
    name = "Riddle: Alone",
    abbr = "?One",
    description = "Riddle: exactly one of you attacks before its next turn.",
    color = { 0.780, 0.650, 0.380 }, -- badge tint (sandstone, the five riddles alike)
    duration = math.huge,
    hideDuration = true,
    hideLog = true, -- the asking is logged by the riddle itself, in a sentence
}
