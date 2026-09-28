-- WILDFIRE: the Blaze's rule, and the Heart of the Wildfire's (models/storm.lua; "Fire, Lightning, and Dirty
-- Thunder", 2026-09-27). The circle's brief says "fires that spread on their own"; hazard_fire spreads only into
-- forest, and the Flows have almost none.
--
-- At the end of the bearer's turn, every fire within 2 of it creeps one tile into plain ground -- the neighbour
-- nearest the bearer's nearest foe. The board shrinks while it lives; kill it and the spreading stops, and what is
-- already down burns out on its own. UNSIDED, as the Cinderstride Boots' fire is: it burns whoever walks into it.
-- (At the END of the turn, not its start as the review put it: traits have no turn-start hook, and the end is where
-- a Blaze has just set the fire its blows kindle.)
return {
    name = "Wildfire",
    description = "At the end of your turn, fire within 2 of you spreads one tile into plain ground.",
    notAReaction = true,
    onTurnEnd = function(ctx) require("models.storm").wildfire(ctx.combat, ctx.unit) end,
}
