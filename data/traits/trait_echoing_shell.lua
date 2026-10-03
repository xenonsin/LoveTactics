-- ECHOING SHELL: the Spellbreaker's (data/items/utility/utility_echoing_shell.lua; "Envy's Bestiary", 2026-10-03,
-- slice C, the Echo's drop). A foe casts an ability within 3 of the bearer, and the bearer is Idle
-- (status_idle): the next thing it uses costs nothing. The shell carries the foe's working back as a free one.
--
-- Idle, not a coined "free spell" badge: the game already has the one word for "the next thing costs nothing"
-- (Idle Hands), and Idle is lifted the moment the bearer uses something, as Idle Hands lifts it.
local REACH = 3

return {
    name = "Echoing Shell",
    description = "When a foe within 3 casts an ability, you become Idle.",
    reach = REACH,
    onAnyCast = function(ctx)
        local u, caster, item = ctx.unit, ctx.caster, ctx.castItem
        if not (u and u.alive and caster and item) or caster.side == u.side or item.type ~= "ability" then return end
        if require("models.combat").unitGap(u, caster) > ctx.param("reach", REACH) then return end
        ctx.applyStatus(u, "status_idle")
    end,
    onCast = function(ctx)
        ctx.clearStatus(ctx.unit, "status_idle")
    end,
}
