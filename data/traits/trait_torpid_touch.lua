-- TORPID TOUCH: the rime slime's rule (Sloth's slime line). Its weapon blows make the target Torpid: their
-- next turn comes later, and they move 1 less. Sloth takes TIME -- a company fighting these loses turns
-- rather than health. `shove` is how far each blow pushes (the Glacier King's is doubled).
return {
    name = "Torpid Touch",
    description = "Its weapon blows make the target Torpid.",
    shove = 3,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        if not (ctx.item and ctx.item.type == "weapon") then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not (target and target.alive) or target.side == ctx.unit.side then return end
        ctx.applyStatus(target, "status_torpid", { magnitude = ctx.param("shove", 3), applier = ctx.unit })
    end,
}
