-- ANSWERED: a Sphinx whose riddle the company met (models/pride_elites.lua; "Pride's Bestiary", 2026-09-30).
-- Unanswered, it takes no damage at all (Status.immuneToDamage); this badge lifts that ward until the Sphinx's
-- next turn ends, when the next riddle is judged and the badge comes off whatever the answer.
--
-- Not a debuff: the company earned it, and a Cure the Sphinx's side might throw must not close the window.
return {
    name = "Answered",
    abbr = "Ans",
    description = "Answered: the riddle was met, and it can be hurt until its next turn ends.",
    color = { 0.960, 0.840, 0.480 }, -- badge tint (sandstone, lit)
    duration = math.huge,
    hideDuration = true,
}
