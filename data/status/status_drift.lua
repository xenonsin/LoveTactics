    -- DRIFT: the snowdrift slime's rule (data/traits/trait_drift.lua). Every turn it ends where it began it
-- gains a stack (+2 Damage, +2 Defense), up to five; a turn it moves sheds them all. Sloth rewarded.
    --
    -- WHETHER IT MOVED is judged from where the bearer began the turn (onTurnStart records it) against where
    -- it ends it (onTurnEnd) -- a shove moves it too, which is fair: it did not hold its ground.
    return {
        name = "Drift",
        abbr = "Drft",
        description = "Drift: more Damage and Defense for every turn it has not moved.",
        color = { 0.690, 0.780, 0.840 },
        duration = math.huge,
        hideDuration = true,
        magnitude = 0,
        statBonus = { damage = 2, defense = 2 },
        statBonusScales = true,
        onTurnStart = function(ctx)
            local s, u = ctx.status, ctx.unit
            s.startX, s.startY = u.x, u.y
        end,
        onTurnEnd = function(ctx)
            local s, u = ctx.status, ctx.unit
            if s.startX == nil then return end
            local moved = u.x ~= s.startX or u.y ~= s.startY
            if moved then s.magnitude = 0
            else s.magnitude = math.min((s.magnitude or 0) + 1, s.cap or 5) end
        end,
    }
