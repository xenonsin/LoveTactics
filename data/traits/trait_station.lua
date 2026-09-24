-- STATION's rule (data/items/utility/utility_station.lua): Pride's rank, worn as bearing -- +3 Defense while
-- an ally of lower level stands beside the bearer. Live, so it is there exactly while they are.
return {
    name = "Station",
    description = "+3 Defense while a lower-level ally stands next to you.",
    live = function(ctx)
        local combat, u = ctx.combat, ctx.unit
        if not combat then return nil end
        local Combat = require("models.combat")
        local mine = (u.char and u.char.level) or 1
        for _, other in ipairs(Combat.unitsNear(combat, u.x, u.y, 1)) do
            if other ~= u and other.alive and other.side == u.side and other.char
                and ((other.char.level or 1) < mine) then
                return { defense = 3 }
            end
        end
        return nil
    end,
}
