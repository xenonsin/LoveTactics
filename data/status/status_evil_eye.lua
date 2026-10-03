-- THE EVIL EYE: the badge the Evil Eye wears for the whole fight (data/traits/trait_the_eye_falls.lua), and the
-- carrier of its look. Reviewed 2026-10-01..03 ("Envy's Bestiary", round 1).
--
-- A STATUS, NOT A TRAIT, because the look comes at the START of the eye's turn and a trait hears no such hook --
-- the same seat the Faceless badge takes for Reshape. At the top of its turn it looks across at the Fairest and,
-- if it can see that body, sours one of its blessings into Rattled (models/envy_oneoffs.lua).
--
-- Not a debuff and never stripped: it is what the body is, not a blessing it holds.
return {
    name = "Evil Eye",
    abbr = "Eye",
    description = "Evil Eye: at the start of its turn it sours one blessing of the Fairest it can see into Rattled.",
    color = { 0.420, 0.620, 0.380 }, -- badge tint (an envious green)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    onTurnStart = function(ctx)
        require("models.envy_oneoffs").evilEye(ctx.combat, ctx.unit)
    end,
}
