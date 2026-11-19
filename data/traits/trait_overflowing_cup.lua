-- Overflowing Cup: a FULL chi bank spent (Combat.spendCharge's onChargeSpent, `full`) quickens the
-- bearer's next action (status_quickened). The item that carries it also lets healing past full bank
-- chi (`charge.from = overhealBurst`, one per overhealing heal), so a monk-priest's surplus grace is
-- the same bank its fists fill.
return {
    name = "Overflowing Cup",
    description = "Consuming a full chi bank makes your next action cost 2 less time.",
    onChargeSpent = function(ctx)
        if ctx.key ~= "chi" or not ctx.full then return end
        ctx.applyStatus(ctx.unit, "status_quickened", { applier = ctx.unit })
    end,
}
