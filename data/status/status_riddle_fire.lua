-- RIDDLE: FIRE -- one of the five riddles a Sphinx asks (models/pride_elites.lua's RIDDLES; "Pride's Bestiary",
-- 2026-09-30). The badge on the asker, naming the question; data/traits/trait_the_riddle.lua judges it at the
-- asker's next turn end and takes it off. Not a debuff and not a blessing -- it is a question, so no Cure lifts
-- it. Met by any strike carrying fire, whether the ward voided it or not.
return {
    name = "Riddle: Fire",
    abbr = "?Fir",
    description = "Riddle: one of you strikes with fire before its next turn.",
    color = { 0.780, 0.650, 0.380 }, -- badge tint (sandstone, the five riddles alike)
    duration = math.huge,
    hideDuration = true,
    hideLog = true, -- the asking is logged by the riddle itself, in a sentence
}
