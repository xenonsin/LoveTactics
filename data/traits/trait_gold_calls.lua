-- GOLD CALLS TO GOLD (round 2's signature, picked over Hoard Quake): lays status_gold_calls for the whole
-- fight, whose turn-start hook slides every heap within 4 one tile toward the golem.
return {
    name = "Gold Calls to Gold",
    description = "At the start of its turn, every coin heap within 4 slides one tile toward it.",
    onCombatStart = function(ctx)
        require("models.status").apply(ctx.combat, ctx.unit, "status_gold_calls")
    end,
}
