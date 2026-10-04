-- BARRED: the Tollkeepers' second line rule (models/toll.lua, Toll.breakBrace), and the half of the Bailiff's
-- Barrier the review's counter names -- "go around the gate, or break the brace with impact". An impact blow on a
-- braced Tollkeeper breaks its brace; on the Bailiff it breaks every brace the Bailiff lent as well.
--
-- On the line's organ rather than the Bailiff's, because the brace it breaks is worn by whoever stands beside the
-- Bailiff, and a blow is heard only by the body it lands on. Not a reaction: a Stunned keeper's brace breaks too.
return {
    name = "Barred",
    description = "An impact blow breaks its brace.",
    notAReaction = true,
    onDamaged = function(ctx)
        require("models.toll").breakBrace(ctx.combat, ctx.unit, ctx.tags)
    end,
}
