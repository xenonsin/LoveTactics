-- BEGRUDGE: the other half of Envy's slime rule. Whenever a foe gains a blessing -- a status that is not a
-- debuff, not a bookkeeping marker, and runs out -- the bearer gains the same one. Heard through
-- Trait.onAnyStatusApplied; the copy is applied `echoed` so nobody hears it again.
return {
    name = "Begrudge",
    description = "Whenever a foe gains a blessing, it gains the same one.",
    onAnyStatusApplied = function(ctx)
        local u, who, st = ctx.unit, ctx.recipient, ctx.status
        if not (u and u.alive and who and st and st.def) or who.side == u.side then return end
        local def = st.def
        if def.debuff or def.hideLog or (st.remaining or 0) > 1e6 then return end
        ctx.applyStatus(u, st.id, { duration = st.remaining, magnitude = st.magnitude, echoed = true })
    end,
}
