-- SCATTER: the Thousand-Winged's death (character_thousand_winged, carried on utility_thousand_wings). Struck to 0
-- it comes apart: half the bats in it fly out again, Scattered for a turn, and the rest are dead
-- (models/swarm.lua's Swarm.scatter). onDeath rather than a threshold, for trait_split's reason: a blow that kills
-- never fires onDamaged.
return {
    name = "Scatter",
    description = "Struck to 0, it comes apart: half the bats in it fly out again, and the rest are dead.",
    notAReaction = true,
    onDeath = function(ctx)
        require("models.swarm").scatter(ctx.combat, ctx.unit)
    end,
}
