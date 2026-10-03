-- EXACT COPY (utility_exact_copy): the Doppelganger's rule. At the opening bell it wears an exact copy of the
-- nearest of the company -- stats, grid and tactics -- and locks it (`faceLocked`), so Reshape never takes it off.
-- Kept until it dies. The copy is worn, not fielded: one body, its own health pool (models/masks.lua).
return {
    name = "Exact Copy",
    description = "At the start of the fight, become an exact copy of the nearest foe until you fall.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local target = require("models.masks").becomeNearest(ctx.combat, u)
        if target then
            ctx.log("system", string.format("The Doppelganger becomes %s.",
                (target.char and target.char.name) or "the nearest of you"))
        end
    end,
}
