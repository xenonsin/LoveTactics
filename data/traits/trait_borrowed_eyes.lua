-- BORROWED EYES (utility_borrowed_eyes): every Invisible foe within 4 is Limned when the fight opens and when the
-- bearer's turn ends, so the whole side can see what the bearer sees. Limned is the existing reveal.
local RADIUS = 4

local function look(ctx)
    local u = ctx.unit
    if not (u and u.alive and ctx.combat) then return end
    local Combat = require("models.combat")
    local Status = require("models.status")
    for _, foe in ipairs(ctx.combat.units or {}) do
        if foe.alive and foe.side ~= u.side and Status.has(foe, "status_invisible")
            and Combat.unitGap(u, foe) <= ctx.param("radius", RADIUS) then
            ctx.applyStatus(foe, "status_limned", { applier = u })
        end
    end
end

return {
    name = "Borrowed Eyes",
    description = "At the start of the fight and the end of your turn, every Invisible foe within 4 is Limned.",
    notAReaction = true,
    radius = RADIUS,
    onCombatStart = look,
    onTurnEnd = look,
}
