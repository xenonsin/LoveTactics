-- Cleansing Ward: a reaction that shrugs off affliction. When a DEBUFF lands on its bearer (the
-- "recipient" side of Trait.onStatusApplied), it strips exactly that status back off and then must
-- recharge -- so the first debuff to touch a warded unit slides off, but a second within the cooldown
-- sticks. Removes only the status that just landed (ctx.status.id), not every debuff.
return {
    name = "Cleansing Ward",
    description = "Shrugs off the first debuff to touch you, then must recharge.",
    magnitude = 20, -- cooldown ticks between triggers
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" then return end
        local landed = ctx.status and ctx.status.def
        if not (landed and landed.debuff) then return end
        if ctx.onCooldown("cleansing_ward") then return end
        ctx.setCooldown("cleansing_ward", ctx.def.magnitude or 20)
        ctx.clearStatus(ctx.unit, ctx.status.id)
        ctx.log("action", string.format("%s's ward burns the affliction away.", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
    end,
}
