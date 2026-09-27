-- THE THRALL: the Blood-Ghoul's rule (data/items/utility/utility_thrall.lua; Wrath's vampires, 2026-09-26). A
-- living body a vampire keeps to drink from: a vampire beside it may Feed on it (ability_feed reads the `thrall`
-- flag). And when it dies, the blood goes everywhere -- every LIVING body beside it Bleeds.
return {
    name = "Thrall",
    description = "A vampire beside it may drink from it. When it dies, every living body beside it Bleeds.",
    thrall = true,
    notAReaction = true,
    onDeath = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return end
        local Combat = require("models.combat")
        local Thirst = require("models.thirst")
        for _, other in ipairs(combat.units or {}) do
            if other.alive and other ~= u and Combat.unitGap(u, other) == 1 and Thirst.isLiving(other) then
                ctx.applyStatus(other, "status_bleed")
            end
        end
    end,
}
