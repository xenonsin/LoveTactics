-- WING BUFFET: at the start of the bearer's turn, every foe standing against it is thrown back (reviewed
-- 2026-09-25, "Avaritia, the Unspent": 2 tiles off the dragon; 1 off the Wingbeat Mantle, her drop).
--
-- A STATUS, because only a status has a turn-start hook; the bearer's trait lays it at the bell and it never
-- ages. `magnitude` is the throw. Measured off the FOOTPRINT: a foe is thrown straight out from the face it
-- stands against, with the lane handed to Combat.knockback as `dest`, because the knockback's own aim reads
-- the anchor and would shove a body beside a 2x2's far column sideways.
return {
    name = "Wing Buffet",
    abbr = "Wing",
    description = "At the start of its turn, every foe beside it is knocked back.",
    color = { 0.620, 0.700, 0.760 }, -- badge tint (downdraft)
    duration = math.huge,
    hideDuration = true,
    magnitude = 2,
    onTurnStart = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit and unit.alive) then return end
        local Combat = require("models.combat")
        local dist = math.max(1, ctx.status.magnitude or 2)
        local w, h = unit.w or 1, unit.h or 1
        local thrown = 0
        for _, foe in ipairs(combat.units or {}) do
            if foe.alive and foe.side ~= unit.side and Combat.unitGap(unit, foe) == 1 then
                local dx = (foe.x + (foe.w or 1) - 1 < unit.x and -1) or (foe.x > unit.x + w - 1 and 1) or 0
                local dy = (foe.y + (foe.h or 1) - 1 < unit.y and -1) or (foe.y > unit.y + h - 1 and 1) or 0
                if dx ~= 0 or dy ~= 0 then
                    Combat.knockback(combat, unit, foe, dist,
                        { dest = { x = foe.x + dx * dist, y = foe.y + dy * dist } })
                    thrown = thrown + 1
                end
            end
        end
        if thrown > 0 then
            ctx.log("action", string.format("%s beats its wings.", (unit.char and unit.char.name) or "It"), unit)
        end
    end,
}
