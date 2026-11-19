-- Static Focus: every Storm the bearer spends raises its magic damage by 1 for the rest of the fight. A
-- live read of the `stormSpent` tally (Engine.onChargeSpent banks one per point spent), so it is never
-- stale and resets with the body at the next fight. The engine getting better the longer it runs.
return {
    name = "Static Focus",
    description = "Each Storm you consume raises your magic damage by 1 for the rest of the fight.",
    live = function(ctx)
        return { magicDamage = require("models.combat").tallyCount(ctx.unit, "stormSpent") }
    end,
}
