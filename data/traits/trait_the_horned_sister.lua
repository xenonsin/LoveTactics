-- THE HORNED SISTER (utility_the_horned_sister). Her sister's fall turns her Horn Out into the full one; the other
-- trigger (her sister struck) is raised from trait_the_hornless_sister's onDamaged, where the blow lands.
local Status = require("models.status")

return {
    name = "The Horned Sister",
    description = "When your sister falls, Full Horn Out for the rest of the fight.",
    hornedSister = true,
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.side == u.side) then return end
        if not require("models.trait").flag(fallen, "hornlessSister") then return end
        if Status.has(u, "status_horn_snapped") then return end
        Status.remove(ctx.combat, u, "status_horn_out")
        if fallen.lastAttacker and fallen.lastAttacker.alive then u.hornTarget = fallen.lastAttacker end
        ctx.applyStatus(u, "status_full_horn_out", { applier = u })
        ctx.log("action", string.format("%s's horn is all the way out.", (u.char and u.char.name) or "She"), u)
    end,
}
