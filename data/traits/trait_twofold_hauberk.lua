-- TWOFOLD HAUBERK (armor_twofold_hauberk): +3 defense for each foe within 2 at the start of the bearer's turn, up to
-- 2 of them. The count is taken at the turn's top (onTurnStart) and held on the trait; the live passive only reads
-- what was counted, so it stays pure and the coat answers the round it was counted for.
return {
    name = "Twofold Hauberk",
    description = "At the start of your turn, gain +3 defense for each foe within 2, up to 2.",
    notAReaction = true,
    radius = 2,
    per = 3,
    cap = 2,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local n = 0
        for _, o in ipairs(ctx.unitsNear(u.x, u.y, ctx.param("radius", 2))) do
            if o ~= u and o.alive and o.side ~= u.side then n = n + 1 end
        end
        ctx.trait.held = math.min(n, ctx.param("cap", 2))
    end,
    live = function(ctx)
        local held = ctx.trait and ctx.trait.held or 0
        if held <= 0 then return nil end
        return { defense = held * ((ctx.def and ctx.def.per) or 3) }
    end,
}
