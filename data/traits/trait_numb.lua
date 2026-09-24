-- NUMB: the frost slime's rule (Sloth's slime line), and Heavy Lids' (utility_heavy_lids). The bearer's
-- landed blows stack Numbed on the target: everything it pays for costs 1 more per stack.
return {
    name = "Numb",
    description = "Your hits inflict Numbed, up to 3 stacks.",
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not (target and target.alive) or target.side == ctx.unit.side then return end
        ctx.applyStatus(target, "status_numbed", { magnitude = 1, applier = ctx.unit })
    end,
}
