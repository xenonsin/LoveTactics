-- WARDROBE: what a velvet slime took goes home when it dies (Combat.returnStripped). The other half of
-- trait_strip, on the same bound body, so no slime can ever take a piece it cannot give back.
return {
    name = "Wardrobe",
    description = "When it falls, everything it took goes back to its owners.",
    onDeath = function(ctx)
        require("models.combat").returnStripped(ctx.combat, ctx.unit)
    end,
}
