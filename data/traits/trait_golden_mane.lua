-- GOLDEN MANE: the Lion's trophy rule (data/items/armor/armor_golden_mane.lua), his roar worn by a knight: a kill
-- the bearer makes heals every ally within 2 by 10% and leaves every foe within 2 Rattled. The Lion's Share heals
-- only lionesses, wherever they stand; a company has none, so the coat heals whoever is near instead.
return {
    name = "Golden Mane",
    description = "When you make a kill, allies within 2 heal 10% and foes within 2 are Rattled.",
    heal = 0.10,
    radius = 2,
    duration = 8,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.lastAttacker == u and fallen.side ~= u.side) then return end
        local Combat = require("models.combat")
        for _, o in ipairs(ctx.unitsNear(u.x, u.y, ctx.param("radius", 2))) do
            if o ~= u and o.alive then
                if o.side == u.side then
                    ctx.heal(o, math.max(1, math.floor(Combat.unreservedMax(o.char, "health") * ctx.param("heal", 0.1) + 0.5)))
                else
                    ctx.applyStatus(o, "status_rattled", { applier = u, duration = ctx.param("duration", 8) })
                end
            end
        end
    end,
}
