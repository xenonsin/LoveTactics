-- WILL NOT BE HURRIED: the Old Spruce's rule (data/items/utility/utility_will_not_be_hurried.lua; "Sloth's
-- Bestiary", 2026-10-04). It never attacks. At the end of each of its turns its roots spread one tile (a wall
-- nothing crosses, data/walls/roots.lua), and a body that ends its turn beside it is Rooted.
--
-- "EACH ROUND" IS THE TREE'S OWN TURN: the game has no rounds, and the tree takes one turn in each. The roots grow
-- toward the nearest of the company and wall the moths as surely as the company (models/sloth_dreamers.lua).
-- `notAReaction`: a tree a moth put to sleep goes on growing.
return {
    name = "Will Not Be Hurried",
    description = "Never attacks. Each turn it grows one more tile of uncrossable root, and a body ending its turn beside it is Rooted.",
    notAReaction = true,
    onTurnEnd = function(ctx)
        if ctx.unit and ctx.unit.alive then require("models.sloth_dreamers").spreadRoots(ctx.combat, ctx.unit) end
    end,
    onAnyTurnEnd = function(ctx)
        if ctx.unit and ctx.unit.alive then
            require("models.sloth_dreamers").rootBeside(ctx.combat, ctx.unit, ctx.actor)
        end
    end,
}
