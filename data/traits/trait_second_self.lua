-- SECOND SELF's rule (data/items/utility/utility_second_self.lua): when the bearer falls, a copy of them at
-- half health stands up beside the body and fights for two turns (Summon.copyOf, timed).
return {
    name = "Second Self",
    description = "When you fall, a copy of you with half your health fights on for two turns.",
    onDeath = function(ctx)
        local u = ctx.unit
        if not u then return end
        local x, y = ctx.openTileNear(u.x, u.y)
        if not x then return end
        local copy = require("models.summon").copyOf(ctx.combat, u, u, x, y, { summoner = false, duration = 10 })
        if copy and copy.char then
            local hp = copy.char.stats.health
            hp.current = math.max(1, math.floor((hp.max or 1) / 2))
            ctx.log("action", string.format("%s stands back up -- or something wearing them does.",
                (u.char and u.char.name) or "It"), { u, copy })
        end
    end,
}
