-- FACELESS: the badge every Faceless wears for the whole fight (data/traits/trait_a_thousand_faces.lua), and the
-- carrier of Reshape. Reviewed 2026-10-01..03 ("Envy's Bestiary").
--
-- A STATUS, NOT A TRAIT, because a trait lives in the grid and a transform swaps the grid: the read has to sit on
-- the unit, where every face it puts on still finds it. At the top of the bearer's turn it reads the nearest foe
-- and wears the face that answers it (models/faces.lua's Faces.reshape).
--
-- Not a debuff, so no Cure lifts it, and never stripped: it is what the body is, not a blessing it holds.
return {
    name = "Faceless",
    abbr = "Face",
    description = "Faceless: at the start of each turn it wears the face that best answers the nearest foe.",
    color = { 0.620, 0.660, 0.640 }, -- badge tint (the grey of an unfinished face)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    onTurnStart = function(ctx)
        require("models.faces").reshape(ctx.combat, ctx.unit)
    end,
}
