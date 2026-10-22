-- THE CHAINED: the Titan, walked up the spire in its chains with a gilded sworn or two for an escort. Approved
-- 2026-09-30 on Pride's bestiary review.
--
-- It crawls a tile a turn and throws you two tiles back with every blow, until you have hurt it to half -- then the
-- chains come off. The sworn are the wall you get thrown into.
--
-- A RUNNER, on the objective pass (2026-10-21): the Titan is crawling for the way down -- the edge the company
-- came in by, so it has to get through them -- and if it gets there it is gone with its chain. A tile a turn
-- gives the company time to catch it; hurting it to half breaks the chains, and then it is not slow. The
-- approved line said the top edge, but the Titan is seated on it: measured, it escaped before anyone had moved
-- on one seed in three, and was cut down in three turns on the others, so the clock never ran.
local Band = require("models.band")

return {
    name = "The Chained",
    kind = "combat",
    weight = 2,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_titan" }, ctx, "character_gilded_sworn", { base = 1, per = 8, max = 2 })
    end,
    objective = {
        type = "killAll", enemy = "the Titan and its sworn",
        escape = { who = "character_titan", region = "near" },
    },
}
