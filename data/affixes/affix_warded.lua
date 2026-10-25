-- WARDED: the first harmful status to land on it is shrugged off, once a fight. The Cleansing Ward's
-- shape (data/traits/trait_cleansing_ward.lua) without its cooldown: one ward, spent once, so the
-- player learns to open on it with something cheap.
return {
    name = "Warded",
    description = "Shrugs off the first harmful status that lands on it.",
    color = { 0.62, 0.52, 0.90 },
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" then return end
        local landed = ctx.status and ctx.status.def
        if not (landed and landed.debuff) then return end
        if (ctx.trait.stacks or 0) > 0 then return end
        ctx.trait.stacks = 1
        ctx.clearStatus(ctx.unit, ctx.status.id)
        ctx.log("action", string.format("%s's ward turns the %s aside.",
            (ctx.unit.char and ctx.unit.char.name) or "It", landed.name or "affliction"), ctx.unit)
    end,
}
