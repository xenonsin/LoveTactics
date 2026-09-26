-- BLOOD UP: the orc Berserker's rule (data/items/utility/utility_blood_up.lua). Approved as pitched (2026-09-26,
-- "The Orcs of Wrath"): the Wrath brief's "a body that cannot stop attacking once started".
--
-- Each turn it lands a hit, +3 Damage (status_blood_up, stacking to five). While Blood Up holds it must strike
-- every turn, and with no foe in reach it hits the nearest body, orc included (the `bloodUp` flag, read by
-- models/rampage.lua). The first turn it lands nothing, the stacks go and it is Spent: its next turn comes a
-- turn later. The answer is to step out of reach for one turn.
return {
    name = "Blood Up",
    description = "Each turn in a row you hit, increase damage by 3. You must strike every turn, and a turn without a hit leaves you Spent.",
    bloodUp = true,
    notAReaction = true,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) > 0 and ctx.unit then ctx.unit._bloodUpHit = true end
    end,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        local Status = require("models.status")
        if u._bloodUpHit then
            u._bloodUpHit = nil
            ctx.applyStatus(u, "status_blood_up")
        elseif Status.has(u, "status_blood_up") then
            ctx.clearStatus(u, "status_blood_up")
            ctx.applyStatus(u, "status_spent")
            ctx.log("action", string.format("%s is Spent.", (u.char and u.char.name) or "It"), u)
        end
    end,
}
