-- SPILLED PURSE (the Gold Golem's trophy, from The Hoard Falls Out): a foe the bearer kills leaves a coin
-- heap on the tile it fell on. It makes heaps on every floor, not only in Greed's cave -- round 2's note,
-- "needs to be useful everywhere" -- so Heart of Gold, Gilt Plating and Veinfinder meet anywhere.
-- It takes GOLD off a kill, never a piece: the no-kill-to-take rule outside Gula is about gear.
return {
    name = "Spilled Purse",
    description = "A foe you kill leaves a coin heap where it fell.",
    onAnyDeath = function(ctx)
        local fallen, unit = ctx.fallen, ctx.unit
        if not (fallen and fallen.lastAttacker == unit and fallen.side ~= unit.side) then return end
        local Golem = require("models.golem")
        if Golem.clear(ctx.combat, fallen.x, fallen.y) then Golem.heap(ctx.combat, fallen.x, fallen.y) end
    end,
}
