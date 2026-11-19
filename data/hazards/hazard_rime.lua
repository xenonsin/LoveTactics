-- Rime: ground a Bombardier's blast left frosted (trait_reactive_blasts). Leaves whoever stands in it
-- Chilled, so a hammer or an axe shatters their armour (status_chilled, Engine.afterWound).
return {
    name = "Rime",
    description = "Inflicts Chilled on units standing on it.",
    tags = { "ice" },
    duration = 20,
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_chilled")
    end,
}
