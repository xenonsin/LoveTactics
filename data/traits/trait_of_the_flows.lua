-- OF THE FLOWS: the Blaze's organ rule (models/storm.lua; "Fire, Lightning, and Dirty Thunder", 2026-09-27).
--
-- The walking half rides a TAG, not this trait: `lavawalk` on utility_of_the_flows, read by Combat.isLavaborn the
-- way `swim` is read for a naga, so Flowwalker's Soles grant it with no trait at all. What is left here is the
-- body's own: at the end of a turn it stands in lava it MENDS -- 13% of its bar, which is 6 at the blueprint's 46 --
-- and water puts it out (status_doused), a cast that lands `water` on it or rain it ends a turn in.
--
-- `notAReaction`: being put out is not an answer the body gives, so a Stunned Blaze is still doused.
local Storm = require("models.storm")

local function inRain(ctx)
    for _, h in ipairs(require("models.hazard").allAt(ctx.combat, ctx.unit.x, ctx.unit.y) or {}) do
        for _, t in ipairs(h.tags or {}) do
            if t == "water" then return true end
        end
    end
    return false
end

return {
    name = "Of the Flows",
    description = "Walks lava as ground, and heals at the end of a turn in it. Water puts it out for 2 turns.",
    notAReaction = true,
    mend = Storm.FLOWS_MEND,
    onDamaged = function(ctx)
        for _, t in ipairs(ctx.tags or {}) do
            if t == "water" then
                ctx.applyStatus(ctx.unit, "status_doused")
                return
            end
        end
    end,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        if inRain(ctx) then ctx.applyStatus(u, "status_doused") end
        if Storm.doused(u) or not Storm.isLava(ctx.combat, u.x, u.y) then return end
        local hp = u.char.stats.health
        if hp.current >= hp.max then return end
        ctx.heal(u, math.max(1, math.floor(hp.max * ctx.param("mend", Storm.FLOWS_MEND) + 0.5)))
    end,
}
