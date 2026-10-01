-- UNBLEMISHED: the elf's racial rule, carried on its grant (data/items/utility/utility_elf_blood.lua). Reviewed
-- 2026-09-30 ("Pride's Bestiary").
--
-- All it does is put the status on at the start of the fight. The status (status_unblemished) carries the
-- lift and ends itself on the first wound, so the rule lives where the badge does and a body that gains the
-- trait mid-fight (a hire who joins late) simply never had it.
return {
    name = "Unblemished",
    description = "Open every fight Unblemished. The first blow that wounds you ends it, and no heal restores it.",
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u and u.alive then ctx.applyStatus(u, "status_unblemished", { applier = u }) end
    end,
}
