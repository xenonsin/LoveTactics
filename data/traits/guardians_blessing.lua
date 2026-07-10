-- Every mend is also a ward: when the bearer casts a healing ability, the target also gains a
-- physical barrier (negating the next physical blow). Turns a healer's reactive patching into
-- proactive shielding. Fires from onCast -- where `ctx.item` is the CAST item (the event's item
-- overrides the trait's granting item), so it reads the heal's own tags to know a heal was cast.
return {
    name = "Guardian's Blessing",
    description = "Your heals also lay a physical barrier on their target.",
    onCast = function(ctx)
        local item = ctx.item
        local tags = (item and item.tags) or {}
        local isHeal = false
        for _, t in ipairs(tags) do if t == "restorative" then isHeal = true break end end
        if not isHeal then return end
        local tgt = ctx.unitAt(ctx.tx, ctx.ty)
        if tgt then ctx.applyStatus(tgt, "physical_barrier") end
    end,
}
