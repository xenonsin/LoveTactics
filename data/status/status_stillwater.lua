    -- STILLWATER: the Stillwater's badge (data/items/utility/utility_stillwater.lua): +3 Defense for as long
-- as the last turn the bearer took, it held its ground.
    --
    -- WHETHER IT MOVED is judged from where the bearer began the turn (onTurnStart records it) against where
    -- it ends it (onTurnEnd) -- a shove moves it too, which is fair: it did not hold its ground.
    return {
        name = "Stillwater",
        abbr = "Stil",
        description = "Stillwater: more Defense after a turn it did not move.",
        color = { 0.690, 0.780, 0.840 },
        duration = math.huge,
        hideDuration = true,
        magnitude = 0,
        statBonus = { defense = 3 },
        statBonusScales = true,
        onTurnStart = function(ctx)
            local s, u = ctx.status, ctx.unit
            s.startX, s.startY = u.x, u.y
        end,
        onTurnEnd = function(ctx)
            local s, u = ctx.status, ctx.unit
            if s.startX == nil then return end
            local moved = u.x ~= s.startX or u.y ~= s.startY
            s.magnitude = moved and 0 or 1
        end,
    }
