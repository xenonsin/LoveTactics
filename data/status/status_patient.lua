    -- PATIENT: the Patient Blade's badge (data/items/utility/utility_patient_blade.lua): +3 Damage on the
-- turn after one the bearer spent holding its ground.
    --
    -- WHETHER IT MOVED is judged from where the bearer began the turn (onTurnStart records it) against where
    -- it ends it (onTurnEnd) -- a shove moves it too, which is fair: it did not hold its ground.
    return {
        name = "Patient",
        abbr = "Pat",
        description = "Patient: more Damage after a turn it did not move.",
        color = { 0.690, 0.780, 0.840 },
        duration = math.huge,
        hideDuration = true,
        magnitude = 0,
        statBonus = { damage = 3 },
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
