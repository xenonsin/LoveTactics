-- UP FROM THE FLOWS: two Blazes come out of the lava on both sides of the company, on Wrath's approach. The
-- teaching fight for Of the Flows and Wildfire: the flows are not a wall to them, and every turn they stand the
-- board is smaller. Approved 2026-09-27 ("Fire, Lightning, and Dirty Thunder", round 1).
local Band = require("models.band")

return {
    name = "Up from the Flows",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_blaze", "character_blaze" }, ctx,
            "character_blaze", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
