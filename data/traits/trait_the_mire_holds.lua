-- THE MIRE HOLDS: the second half of the Bog-Bound's line rule, carried on their organ (utility_bog_bound;
-- "Sloth's Bestiary", 2026-10-04, slice C). A body that starts its turn beside one of the Bog-Bound pays 2
-- movement to step away from it: the peat drags at its legs. Shoves and pulls ignore the toll.
--
-- A FLAG, priced where every step is priced (Combat's stepTerrainCost -> models/sloth_bog.lua's mireToll), so the
-- move overlay, a steered route and the walk all agree. A forced move never walks, so it never pays. Asked of
-- the foes of the bearer only: its own line wades through the same peat it lies in.
return {
    name = "The Mire Holds",
    description = "A foe that starts its turn beside you pays 2 movement to step away from you.",
    mireHolds = true,
    notAReaction = true,
    onCombatStart = function() require("models.sloth_bog").live = true end,
}
