-- SENTENCED: the Throne's chain (reviewed 2026-09-30, "Pride's Bestiary"). Every third turn of the Throne's, two
-- of the company are bound to each other -- the two standing furthest apart (models/choir.lua) -- and each wears
-- this naming the other (`partner`, on the instance). Whenever either ENDS a turn more than 2 tiles from its
-- partner, both take holy damage.
--
-- So the sentence is a positional ask, not a clock: the pair has a few turns to close up, and a company that
-- gathers around the chained two is a company standing in a knot on a floor the Decree is lighting. A debuff, so
-- a Cure lifts it -- off one of them, which breaks the chain for both (the other has nobody left to be far from).
return {
    name = "Sentenced",
    abbr = "Sent",
    description = "Chained to another: ending a turn more than 2 tiles from them hurts you both.",
    color = { 0.930, 0.840, 0.520 }, -- badge tint (the Throne's gold)
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN: long enough to have to answer it, short enough to wait out
    magnitude = 8, -- holy damage to each, per turn ended apart
    debuff = true,
    gap = 2,
    onTurnEnd = function(ctx)
        local u, st = ctx.unit, ctx.status
        local partner = st and st.partner
        if not (u and u.alive) then return end
        local Status = require("models.status")
        if not (partner and partner.alive and Status.has(partner, "status_sentenced")) then
            ctx.expire()
            return
        end
        local Combat = require("models.combat")
        if Combat.unitGap(u, partner) <= (st.def.gap or 2) then return end
        local n = st.magnitude or st.def.magnitude
        ctx.log("status", string.format("%s strayed too far from %s: the sentence falls on both.",
            (u.char and u.char.name) or "Unit", (partner.char and partner.char.name) or "a partner"), u)
        ctx.damage(u, n, { "holy" })
        if partner.alive then ctx.damage(partner, n, { "holy" }) end
    end,
}
