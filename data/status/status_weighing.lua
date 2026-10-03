-- WEIGHING: the badge a Jackal Weigher wears for the whole fight (data/traits/trait_the_weighing.lua), and the
-- carrier of the scale. Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- A STATUS, NOT A TRAIT, for the Evil Eye's reason: the weighing comes at the start of the Weigher's turn, and
-- only a status hears that. It sets the two of the company nearest it on the scale (models/envy_oneoffs.lua):
-- the heavier heart is Weighed, the lighter Spared.
--
-- Not a debuff and never stripped: it is what the body is for.
return {
    name = "Weighing",
    abbr = "Wgh",
    description = "Weighing: at the start of its turn it weighs the two foes nearest it against each other.",
    color = { 0.760, 0.640, 0.300 }, -- badge tint (the brass of the scale)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    onTurnStart = function(ctx)
        require("models.envy_oneoffs").weigh(ctx.combat, ctx.unit)
    end,
}
