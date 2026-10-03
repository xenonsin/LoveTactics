-- CAST BY YOU: the Shade's rule, on its organ (data/items/utility/utility_cast_by_you.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary", round 1).
--
-- It lives in shadow: beside a wall or ridge it is Unseen, on open sand it is Limned. The read rides the badge
-- (status_cast_by_you), which hears every tile the body is walked or shoved onto and the end of its turn; this
-- trait puts the badge on at the bell and reads the ground it opens on.
return {
    name = "Cast by You",
    description = "Unseen beside a wall or ridge, and Limned on open ground.",
    onCombatStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        ctx.applyStatus(u, "status_cast_by_you", { applier = u })
        require("models.envy_oneoffs").reshadow(ctx.combat, u, true)
    end,
}
