-- Opportunist: a reaction that rewards inflicting debuffs. When its bearer lands ANY debuff on a foe
-- (the "applier" side of Trait.onStatusApplied), it grants itself Haste and then must recharge. The
-- landed status is read through ctx.status.def; ctx.def is this trait's own blueprint (the cooldown).
-- Note the bearer's initiative is 0 during its own turn, so we hasten (cheaper future actions) rather
-- than shave an initiative that isn't there yet.
return {
    name = "Opportunist",
    description = "When you afflict a foe with a debuff, seize the moment -- you gain Haste. Then it must recharge.",
    magnitude = 14, -- cooldown ticks between triggers
    onStatusApplied = function(ctx)
        if ctx.role ~= "applier" then return end
        local landed = ctx.status and ctx.status.def
        if not (landed and landed.debuff) then return end
        local foe = ctx.recipient
        if not foe or foe.side == ctx.unit.side then return end
        if ctx.onCooldown("opportunist") then return end
        ctx.setCooldown("opportunist", ctx.def.magnitude or 14)
        ctx.applyStatus(ctx.unit, "hasted")
        ctx.log("action", string.format("%s seizes the opening!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
    end,
}
