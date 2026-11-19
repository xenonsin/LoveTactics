-- Hollow Idol: every ability the bearer casts deals 2 more for each EMPTY cell in its 3x3 grid. A lean
-- build's payoff: fewer items, each one bigger. Read live off the grid the moment the blow is priced, so
-- the forecast and the blow agree (Trait.outgoingDamageBonus).
return {
    name = "Hollow Idol",
    description = "Your abilities deal 2 more for each empty grid slot.",
    perSlot = 2,
    damageBonusVs = function(ctx)
        if not (ctx.blow and ctx.blow.type == "ability") then return 0 end
        local inv = ctx.unit.char and ctx.unit.char.inventory
        if not inv then return 0 end
        local empty = 0
        for i = 1, require("models.character").MAX_INVENTORY do
            if inv[i] == nil or inv[i] == false then empty = empty + 1 end
        end
        return empty * ctx.param("perSlot", ctx.def.perSlot or 2)
    end,
}
