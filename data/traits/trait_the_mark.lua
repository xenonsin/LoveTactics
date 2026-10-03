-- THE MARK: whoever fells the bearer takes 7 times a blow back (models/kinslayer.lua's Kinslayer.mark). Two
-- readings of "a blow", told apart by `measure` (Trait.param), so one rule serves both sides of the fight:
--   "killingBlow"  the blow that felled the bearer -- The Mark, the duelist's drop (the default)
--   "lastHit"      the bearer's own last landed hit -- the Kinslayer's, on his organ
-- A killer is the attacker of the felling blow; a burn, a hazard, a trap or a thrown bomb leaves none.
return {
    name = "The Mark",
    description = "A foe that lands a killing blow on it takes 7 times a blow back.",
    times = 7,
    measure = "killingBlow",
    notAReaction = true,
    onDeath = function(ctx)
        require("models.kinslayer").mark(ctx.combat, ctx.unit, ctx.param("times", 7), ctx.param("measure", "killingBlow"))
    end,
}
