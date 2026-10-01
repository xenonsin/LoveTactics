-- RIDDLE: DISTANCE -- one of the five riddles a Sphinx asks (models/pride_elites.lua's RIDDLES; "Pride's
-- Bestiary", 2026-09-30). Met by a strike that catches a foe 3 or more tiles from the striker: a bow, a wand,
-- a spell thrown from the back line.
return {
    name = "Riddle: Distance",
    abbr = "?Far",
    description = "Riddle: one of you strikes from 3 or more tiles away before its next turn.",
    color = { 0.780, 0.650, 0.380 }, -- badge tint (sandstone, the five riddles alike)
    duration = math.huge,
    hideDuration = true,
    hideLog = true, -- the asking is logged by the riddle itself, in a sentence
}
