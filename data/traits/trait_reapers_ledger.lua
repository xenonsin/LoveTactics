-- Reaper's Ledger: a killing blow struck with a WEAPON sitting next to the ledger in the grid refunds
-- what that blow cost, and the bearer gets two free steps (status_reapers_stride: +2 movement until the
-- end of its next turn). The hunter's Reaper engine, paid in tempo rather than in damage (the author's
-- call, round 2): kill, step, kill.
return {
    name = "Reaper's Ledger",
    description = "A kill with a weapon next to it refunds the blow's cost and grants 2 free steps.",
    onKill = function(ctx)
        local blow = ctx.blow
        local ledger = ctx.trait.item
        if not (blow and blow.type == "weapon" and ledger and ctx.unit.char) then return end
        local Combat = require("models.combat")
        if not Combat.gridAdjacent(ctx.unit.char, ledger, blow) then return end
        local ab = blow.activeAbility
        for _, c in ipairs(require("models.item").costs(ab)) do
            if (c.amount or 0) > 0 and c.stat ~= "health" then ctx.restore(ctx.unit, c.stat, c.amount) end
        end
        ctx.applyStatus(ctx.unit, "status_reapers_stride", { applier = ctx.unit })
        ctx.log("action", string.format("%s marks the kill and moves on.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"))
    end,
}
