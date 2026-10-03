-- THE FAVOURED ONE: the Kinslayer's hunt (models/kinslayer.lua). He keeps count of every blessing that lands fresh
-- on a foe (onAnyStatusApplied; heals bank on the patient through Combat.applyHeal's `healedTaken` tally), and at
-- the end of every turn the Favoured badge moves to whoever leads the count. `huntsFavoured` is the flag
-- AI.preempt reads to send him at that body.
return {
    name = "The Favoured One",
    description = "Hunts the foe healed or blessed most this fight.",
    huntsFavoured = true,
    notAReaction = true,
    onAnyStatusApplied = function(ctx)
        require("models.kinslayer").noteBlessing(ctx.unit, ctx.recipient, ctx.status)
    end,
    onTurnEnd = function(ctx) require("models.kinslayer").restamp(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx) require("models.kinslayer").restamp(ctx.combat, ctx.unit) end,
}
