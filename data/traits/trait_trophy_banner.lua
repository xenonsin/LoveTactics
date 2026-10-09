-- TROPHY BANNER: the orc warlord's race item (data/items/utility/utility_trophy_banner.lua, "The Rift's
-- Adventurers", slice D). An ally that makes a kill while standing in the field of a banner the bearer planted
-- (a zone whose owner is a standard the bearer summoned -- Rally Banner, Muster Banner and the rest) makes the
-- BEARER Proven, through status_proven's own three-stack cap.
--
-- Read off where the killer stands when the body drops, which is the board the field is drawn on. The bearer's
-- own kills are Proven's business already, and are not counted twice.
local function inField(combat, bearer, killer)
    local Hazard = require("models.hazard")
    for _, h in ipairs(Hazard.allAt(combat, killer.x, killer.y)) do
        local owner = h.owner
        if owner and owner.alive and owner.summoner == bearer then return true end
    end
    return false
end

return {
    name = "Trophy Banner",
    description = "When an ally inside your banner's field makes a kill, you become Proven.",
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        local killer = fallen and fallen.lastAttacker
        if not (u and u.alive and killer and killer ~= u and killer.alive) then return end
        if killer.side ~= u.side or fallen.side == u.side then return end
        if not inField(ctx.combat, u, killer) then return end
        ctx.applyStatus(u, "status_proven", { applier = u })
    end,
}
