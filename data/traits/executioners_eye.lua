-- Executioner's Eye: a reaction that turns hard control into a kill window. When its bearer STUNS or
-- FREEZES a foe (the "applier" side of Trait.onStatusApplied), it also Marks that foe -- stacking a
-- defense cut onto the lockdown so the party's follow-up lands harder. Then it must recharge. Reads the
-- landed status id through ctx.status; ctx.def is this trait's own blueprint (the cooldown).
return {
    name = "Executioner's Eye",
    description = "When you stun or freeze a foe, mark it for the kill. Then it must recharge.",
    magnitude = 8, -- cooldown ticks between triggers
    onStatusApplied = function(ctx)
        if ctx.role ~= "applier" then return end
        local id = ctx.status and ctx.status.id
        if id ~= "stun" and id ~= "freeze" then return end
        local foe = ctx.recipient
        if not foe or not foe.alive or foe.side == ctx.unit.side then return end
        if ctx.onCooldown("executioners_eye") then return end
        ctx.setCooldown("executioners_eye", ctx.def.magnitude or 8)
        ctx.applyStatus(foe, "mark")
        ctx.log("action", string.format("%s marks its prey.", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
    end,
}
