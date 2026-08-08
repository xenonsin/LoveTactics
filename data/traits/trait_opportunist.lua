-- Opportunist: a reaction that rewards inflicting debuffs. When its bearer lands ANY debuff on a foe
-- (the "applier" side of Trait.onStatusApplied), it grants itself Haste and then goes on cooldown. The
-- landed status is read through ctx.status.def; ctx.def is this trait's own blueprint (the cooldown).
-- Note the bearer's initiative is 0 during its own turn, so we hasten (cheaper future actions) rather
-- than shave an initiative that isn't there yet.
return {
    name = "Opportunist",
    description = "When you afflict a foe with a debuff, seize the moment. You gain Haste. Then it goes on cooldown.",
    cooldown = 14, -- ticks between triggers
    onStatusApplied = function(ctx)
        if ctx.role ~= "applier" then return end
        local landed = ctx.status and ctx.status.def
        if not (landed and landed.debuff) then return end
        local foe = ctx.recipient
        if not foe or foe.side == ctx.unit.side then return end
        if ctx.onCooldown("trait_opportunist") then return end
        ctx.setCooldown("trait_opportunist", ctx.def.cooldown or 14)
        ctx.applyStatus(ctx.unit, "status_hasted")
        ctx.log("action", string.format("%s seizes the opening!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
    end,
}
