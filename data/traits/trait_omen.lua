-- OMEN: the Hollow Crown's tell, carried out (data/items/utility/utility_omen.lua; slice D). The Crown shows what it
-- will do a turn ahead; this hands its bearer the same lesson from the other side -- every wind-up a foe begins is a
-- tell, and the bearer's whole line moves on it. Each time a foe begins winding up (its Channeling lands), every ally
-- of the bearer, the bearer included, is Hasted for a turn.
--
-- ONCE PER FOE PER ROUND. Flagged on review as strong against a body that does nothing but wind up; a boss that
-- channels twice between two of the bearer's turns would otherwise keep the company Hasted end to end. Each foe can
-- trip it once until the bearer's own turn comes round again (`trait.seen`, cleared at its turn start).
return {
    name = "Omen",
    description = "Each time a foe winds up, every ally gains Haste for a turn. Once per foe each round.",
    onTurnStart = function(ctx) ctx.trait.seen = {} end,
    onAnyStatusApplied = function(ctx)
        local u, foe, st = ctx.unit, ctx.recipient, ctx.status
        if not (u and u.alive and foe and st) or st.id ~= "status_channeling" then return end
        if foe.side == u.side then return end
        ctx.trait.seen = ctx.trait.seen or {}
        if ctx.trait.seen[foe] then return end
        ctx.trait.seen[foe] = true
        local ticks = require("models.status").TICKS_PER_TURN
        for _, ally in ipairs(ctx.combat.units or {}) do
            if ally.alive and ally.side == u.side then
                ctx.applyStatus(ally, "status_hasted", { duration = ticks, applier = u })
            end
        end
        ctx.log("status", string.format("%s reads the omen: the line quickens.", (u.char and u.char.name) or "It"))
    end,
}
