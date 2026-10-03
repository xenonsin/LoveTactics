-- WEAVER'S SHUTTLE: the Theurge's (data/items/utility/utility_weavers_shuttle.lua; "Envy's Bestiary", 2026-10-03,
-- slice C, Arachne's drop). When a foe casts the same ability a second time, the bearer is lent a copy of it
-- (Combat.lendItem) to cast once. The copy is recalled when it is used and swept at the end of the fight, as the
-- Copycat's and the Echo's loans are.
--
-- Counted per ability across every foe, on the bearer (`unit.shuttle`), and lent once per ability a fight. A
-- piece marked `noCopy` is never lent, and a loan is never lent again.
return {
    name = "Weaver's Shuttle",
    description = "When a foe casts the same ability a second time, you get a copy of it to cast once.",
    onAnyCast = function(ctx)
        local u, caster, item = ctx.unit, ctx.caster, ctx.castItem
        if not (u and u.alive and caster and item and item.id) or caster.side == u.side then return end
        if item.type ~= "ability" or item.noCopy or item.onLoan or item.woven then return end
        u.shuttle = u.shuttle or { seen = {}, lent = {} }
        local n = (u.shuttle.seen[item.id] or 0) + 1
        u.shuttle.seen[item.id] = n
        if n >= 2 and not u.shuttle.lent[item.id] then
            local Combat = require("models.combat")
            if Combat.lendItem(ctx.combat, u, item.id, { woven = true }) then u.shuttle.lent[item.id] = true end
        end
    end,
    onCast = function(ctx)
        if ctx.item and ctx.item.woven then
            require("models.combat").recallLoan(ctx.combat, ctx.unit, ctx.item)
        end
    end,
}
