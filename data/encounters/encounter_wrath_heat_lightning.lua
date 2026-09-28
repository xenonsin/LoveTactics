-- HEAT LIGHTNING: two Arcs across a flow, on Wrath's approach. The teaching fight for Static and Forking, and for
-- the long way round: the lava hides nobody, so reaching them is a walk. Approved 2026-09-27 ("Fire, Lightning, and
-- Dirty Thunder", round 1).
local Band = require("models.band")

return {
    name = "Heat Lightning",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_arc", "character_arc" }, ctx,
            "character_arc", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
