-- A drilled line-soldier: the bearer stands stronger the more allies flank it. At combat start it
-- gains defense and magic defense for each ally standing orthogonally adjacent -- a wall in a huddle,
-- exposed alone. Measured once, when the line is set (there is no per-turn hook), so position at the
-- opening bell is what counts.
return {
    name = "Formation Fighter",
    description = "Gains defense for each ally standing adjacent at battle's start.",
    onCombatStart = function(ctx)
        local n = 0
        for _, o in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, 1)) do
            if o ~= ctx.unit and o.side == ctx.unit.side then n = n + 1 end
        end
        if n > 0 then
            ctx.addBonus("defense", 2 * n)
            ctx.addBonus("magicDefense", 1 * n)
        end
    end,
}
