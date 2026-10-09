-- COMMAND: the Archon Duke's second rule, worn in both its bodies (character_archon_duke, character_archon_duke_
-- ascended; "The Crown's Bestiary", slice A, 2026-10-09). Archons within 3 of it act before the company does.
--
-- THE SMALLEST COHERENT VERSION. The timeline has no rounds to nudge at the top of, so the Duke's own turn stands in
-- for one: at the bell and at the end of each of its turns, every other Archon within 3 is pulled one tick ahead of
-- the company's soonest body (models/archon_court.lua's command). Pulled, never pushed, and never below 0.
return {
    name = "Command",
    description = "At the end of its turn, Archons within 3 of it move ahead of every foe in the turn order.",
    commandsTheCourt = true,
    reach = 3,
    onCombatStart = function(ctx) require("models.archon_court").command(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) require("models.archon_court").command(ctx.combat, ctx.unit) end,
}
