-- THE HEIR'S TORC: the orc Warchief's first drop (data/items/utility/utility_heirs_torc.lua; approved as pitched,
-- 2026-09-26, "The Orcs of Wrath"). When an ally falls, the bearer takes up its fight: heal 25% of max health and
-- +3 Damage for the rest of the fight, three times at most (status_taken_up).
return {
    name = "Heir's Torc",
    description = "When an ally falls, heal 25% of your max health and increase damage by 3 for the fight, up to 3 times.",
    notAReaction = true,
    share = 0.25,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.side == u.side and fallen ~= u) then return end
        if fallen.summoner or (fallen.char and (fallen.char.tier or 1) == 0) then return end
        local Combat = require("models.combat")
        ctx.heal(u, math.floor(Combat.unreservedMax(u.char, "health") * ctx.param("share", 0.25) + 0.5))
        ctx.applyStatus(u, "status_taken_up")
    end,
}
