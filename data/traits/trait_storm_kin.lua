-- STORM-KIN: the Blaze and the Arc are two halves of one storm (models/storm.lua; "Fire, Lightning, and Dirty
-- Thunder", 2026-09-27). At the end of ANY turn a Blaze and an Arc of one side standing next to each other fuse into
-- the Thunderhead. Carried on their natural weapons.
--
-- The `stormKin` flag is what AI.POSTURES.gather reads to walk each half to its other (Storm.partner). A half that
-- falls while the torn storm is held inside it takes the storm with it once no half is left standing.
return {
    name = "Storm-Kin",
    description = "Ending any turn beside its other half, a Blaze and an Arc fuse into the Thunderhead.",
    stormKin = true,
    notAReaction = true,
    onTurnEnd = function(ctx) require("models.storm").turnEnd(ctx.combat) end,
    onAnyTurnEnd = function(ctx) require("models.storm").turnEnd(ctx.combat) end,
    onDeath = function(ctx) require("models.storm").halfFallen(ctx.combat, ctx.unit) end,
}
