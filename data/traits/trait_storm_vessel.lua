-- Storm Vessel: the Storm the vessel is holding steadies its bearer, +1 magic defense a charge, read
-- live off the pool so it falls the moment a spell beside the vessel empties it. What the vessel gives
-- a body on its own; the spell beside it is what it is for (docs/engines.md).
return {
    name = "Storm Vessel",
    description = "Gain 1 magic defense for each Storm held.",
    live = function(ctx)
        return { magicDefense = require("models.combat").chargePool(ctx.unit, "storm") }
    end,
}
