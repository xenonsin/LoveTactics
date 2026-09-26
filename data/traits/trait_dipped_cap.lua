-- THE DIPPED CAP: the drop's rule (data/items/utility/utility_dipped_cap.lua). A foe the bearer killed (its
-- lastAttacker) leaves the bearer Invisible -- which ends at the bearer's next turn, i.e. when it next acts --
-- and Dipped, which Combat.forcesCrit reads against a foe below half and the landing blow spends.
return {
    name = "The Dipped Cap",
    description = "A kill makes you Invisible until you next act, and your next strike on a foe below half is a certain critical.",
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.lastAttacker == u and fallen.side ~= u.side) then return end
        ctx.applyStatus(u, "status_invisible")
        ctx.applyStatus(u, "status_dipped")
    end,
}
