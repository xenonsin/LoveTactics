-- IDLE HANDS' rule (data/items/utility/utility_idle_hands.lua): the frost slime's Numb, inverted. The
-- bearer opens each battle Idle, and the first thing they use costs nothing.
return {
    name = "Idle Hands",
    description = "The first thing you use each battle costs nothing.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_idle")
    end,
    onCast = function(ctx)
        ctx.clearStatus(ctx.unit, "status_idle")
    end,
}
