-- TIME IS PAST: the Artificer's (data/items/utility/utility_time_is_past.lua; "Envy's Bestiary", 2026-10-03, slice
-- C, the Brazen Head's drop). The head's last word, kept for whoever carries it: when the bearer falls, every foe
-- within 3 is Stunned.
local RADIUS = 3

return {
    name = "Time Is Past",
    description = "When you fall, every foe within 3 is Stunned.",
    radius = RADIUS,
    onDeath = function(ctx)
        local u = ctx.unit
        if not u then return end
        for _, foe in ipairs(ctx.unitsNear(u.x, u.y, ctx.param("radius", RADIUS))) do
            if foe ~= u and foe.side ~= u.side then ctx.applyStatus(foe, "status_stun", { applier = u }) end
        end
    end,
}
