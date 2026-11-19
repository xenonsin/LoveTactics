-- Oil Slick: ground a Bombardier's blast left slick (trait_reactive_blasts). Leaves whoever stands in it
-- Oiled, so the next fire that finds them goes up (status_oiled, Engine.ignite).
return {
    name = "Oil Slick",
    description = "Inflicts Oiled on units standing on it.",
    tags = { "oil" },
    duration = 20,
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_oiled")
    end,
}
