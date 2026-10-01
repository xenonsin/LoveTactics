-- RIDDLE: TOGETHER -- one of the five riddles a Sphinx asks (models/pride_elites.lua's RIDDLES; "Pride's
-- Bestiary", 2026-09-30). Met when two different bodies of the asked side strike the same foe before the
-- asker's next turn. Against a Sphinx that stands alone, the foe is the Sphinx.
return {
    name = "Riddle: Together",
    abbr = "?Two",
    description = "Riddle: two of you strike the same foe before its next turn.",
    color = { 0.780, 0.650, 0.380 }, -- badge tint (sandstone, the five riddles alike)
    duration = math.huge,
    hideDuration = true,
    hideLog = true, -- the asking is logged by the riddle itself, in a sentence
}
