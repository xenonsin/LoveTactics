-- SPENT: what a Berserker's streak costs when it breaks (data/traits/trait_blood_up.lua). The turn it lands
-- nothing, it loses its next turn -- the Stun's own shove down the turn order, as its own price rather than a
-- thing done to it, so it is not a debuff for a Cure to lift.
return {
    name = "Spent",
    abbr = "Spnt",
    description = "Spent: the next turn comes later.",
    color = { 0.520, 0.470, 0.430 }, -- badge tint (grey, emptied)
    magnitude = 5,
    shovesInitiative = "magnitude",
    duration = 5,
    disablesReactions = true,
    onApply = function(ctx)
        if require("models.status").shoveProof(ctx.unit, "status_spent") then return end
        ctx.unit.initiative = ctx.unit.initiative + (ctx.magnitude or 0)
    end,
    onTurnStart = function(ctx) ctx.expire() end,
}
