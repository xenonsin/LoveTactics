-- THE PIT-FIGHTER'S BELT: the Challenge turned round (data/items/utility/utility_pit_fighters_belt.lua; approved as
-- pitched, 2026-09-26, "The Orcs of Wrath"). The bearer takes half damage from every foe except the one it last
-- struck (status_single_combat, whose `exempt` this keeps current). For the body that picks one fight and stays
-- in it; unlike Duelbound it holds nobody in place.
local function belt(ctx)
    local u = ctx.unit
    if not (u and u.alive) then return nil end
    local Status = require("models.status")
    if not Status.has(u, "status_single_combat") then ctx.applyStatus(u, "status_single_combat") end
    return Status.get(u, "status_single_combat")
end

return {
    name = "Pit-Fighter's Belt",
    description = "Take half damage from every foe except the one you last struck.",
    notAReaction = true,
    onCombatStart = function(ctx) belt(ctx) end,
    onCast = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat and (ctx.damageDealt or 0) > 0 and ctx.tx) then return end
        local struck = require("models.combat").unitAt(combat, ctx.tx, ctx.ty)
        if not (struck and struck.side ~= u.side) then return end
        local s = belt(ctx)
        if s then s.exempt = struck end
    end,
}
