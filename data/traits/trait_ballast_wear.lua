-- GOLDEN BALLAST'S PRICE (the Gold Golem's trophy, from its gold plates): each impact blow the bearer
-- stands through wears 2 of the ballast's Defense off for the rest of the fight (status_ballast_worn, three
-- times at most -- the whole +6). The unmovable half is the Unheld's own trait, carried beside this.
return {
    name = "Golden Ballast",
    description = "Each impact blow you take wears 2 Defense off the ballast for the fight.",
    notAReaction = true,
    onDamaged = function(ctx)
        if not require("models.golem").hasTag(ctx.tags, "impact") then return end
        require("models.status").apply(ctx.combat, ctx.unit, "status_ballast_worn", { magnitude = 1 })
    end,
}
