-- THE USURER'S SCALE's rule (data/items/utility/utility_usurers_scale.lua): the King Slime's interest,
-- charged to a foe. Every blow the bearer lands writes one more stack of Owed on the body it hit, so the
-- same foe costs more with every hit -- a debt that compounds, up to six.
return {
    name = "Usurer's Scale",
    description = "Your hits inflict Owed on the foe, up to 6 stacks.",
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not (target and target.alive) or target.side == ctx.unit.side then return end
        ctx.applyStatus(target, "status_owed", { magnitude = 1, applier = ctx.unit })
    end,
}
