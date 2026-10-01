-- THE CHAINED: the Titan, walked up the spire in its chains with a gilded sworn or two for an escort. Approved
-- 2026-09-30 on Pride's bestiary review.
--
-- It crawls a tile a turn and throws you two tiles back with every blow, until you have hurt it to half -- then the
-- chains come off. The sworn are the wall you get thrown into.
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
}
