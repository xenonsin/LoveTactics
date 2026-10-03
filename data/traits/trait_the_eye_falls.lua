-- THE EYE FALLS ON GOOD FORTUNE: the Evil Eye's rule, on its organ (data/items/utility/utility_the_evil_eye.lua).
-- Reviewed 2026-10-01..03 ("Envy's Bestiary", round 1).
--
-- At the bell it opens its eye: the badge (status_evil_eye) carries the look, because the look comes at the START
-- of each of its turns and only a status hears that. The look itself is models/envy_oneoffs.lua's.
return {
    name = "The Eye Falls on Good Fortune",
    description = "At the start of its turn, sours one blessing of the Fairest it can see into Rattled.",
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u and u.alive then ctx.applyStatus(u, "status_evil_eye", { applier = u }) end
    end,
}
