-- WILL NOT ADMIT THE WOUND: the Elf Highborn's (data/items/utility/utility_will_not_admit.lua). Approved 2026-09-30
-- ("Pride's Bestiary"). The one elf whose Unblemished COMES BACK: if it goes a full round without being struck, it
-- is Unblemished again, and the badge returning is the tell.
--
-- A FULL ROUND is measured from the end of one of its own turns to the end of the next. A wound in between (the
-- `struck` latch, set on any blow that drew blood) spends the round; the first turn's end only starts the count,
-- so the opening of a fight is never a round it was "not struck" in. A heal still gives nothing back -- what
-- returns it is time untouched, not health.
return {
    name = "Will Not Admit the Wound",
    description = "A full round without being struck makes you Unblemished again.",
    notAReaction = true,
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 then ctx.trait.struck = true end
    end,
    onTurnEnd = function(ctx)
        local t, u = ctx.trait, ctx.unit
        if t.counting and not t.struck and u and u.alive
            and not require("models.status").has(u, "status_unblemished") then
            ctx.applyStatus(u, "status_unblemished", { applier = u })
            ctx.log("status", string.format("%s will not admit the wound.", (u.char and u.char.name) or "The elf"), u)
        end
        t.counting, t.struck = true, false
    end,
}
