-- THE LAUREL OF RENOWN: the Elf-Lord's drop, worn (data/items/utility/utility_laurel_of_renown.lua). Approved
-- 2026-09-30 ("Pride's Bestiary"). His Renown made a company's, and made smaller: when the wearer or any ally makes
-- a kill (the fallen's lastAttacker), the wearer and every ally within 3 of the wearer gain a stack of Laurels
-- (status_laurels, +1 Damage each, up to 5, for the fight). No race on it: what was the court's is the company's.
return {
    name = "Laurel of Renown",
    description = "When you or an ally makes a kill, you and allies within 3 gain Laurels, up to 5.",
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        local killer = fallen and fallen.lastAttacker
        if not (u and u.alive and killer and killer.side == u.side and fallen.side ~= u.side) then return end
        ctx.applyStatus(u, "status_laurels", { applier = u })
        for _, other in ipairs(ctx.unitsNear(u.x, u.y, 3)) do
            if other ~= u and other.alive and other.side == u.side then
                ctx.applyStatus(other, "status_laurels", { applier = u })
            end
        end
    end,
}
