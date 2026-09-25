-- SMELLING SALTS: the first Charm of each fight does not take. Settled on review 2026-09-25 as a
-- TRIGGERED counter rather than a cure ("there's already an item that cures debuffs, but this can be a
-- triggered counter"): nothing to spend a turn on, it simply answers the charm the moment it lands.
--
-- Removed rather than refused, through Status.remove, so the side-flip the charm already made reverts by
-- the ordinary path (status_charm's onExpire) -- the same way Xin's Unbidden rule sheds one. Once per fight:
-- the instance is minted per battle (Trait.attach), so the spent flag lives on it.
return {
    name = "Smelling Salts",
    description = "The first time each fight you are Charmed, you come to your senses at once.",
    onStatusApplied = function(ctx)
        local st = ctx.status
        if ctx.role ~= "recipient" or not st or st.id ~= "status_charm" or ctx.trait.spent then return end
        ctx.trait.spent = true
        ctx.clearStatus(ctx.unit, "status_charm")
        ctx.log("status", string.format("%s comes to their senses.",
            (ctx.unit.char and ctx.unit.char.name) or "The bearer"), ctx.unit)
    end,
}
