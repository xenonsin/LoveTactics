-- LODESTONE (the Gold Golem's trophy): lays status_lodestone for the whole fight, whose turn-start hook
-- drags every foe within 3 one tile toward the bearer.
return {
    name = "Lodestone",
    description = "At the start of your turn, every foe within 3 is dragged one tile toward you.",
    onCombatStart = function(ctx)
        require("models.status").apply(ctx.combat, ctx.unit, "status_lodestone")
    end,
}
