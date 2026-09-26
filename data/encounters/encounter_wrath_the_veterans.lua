-- THE VETERANS: the same line with the scars already on, on Wrath's approach (approved as pitched, 2026-09-26, "The
-- Orcs of Wrath"). Veterans open Proven twice over, and one more kill makes three. The scars show before the
-- company engages, so it can see which to cut down first.
local Band = require("models.band")

return {
    name = "The Veterans",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_orc_berserker" }, ctx,
            "character_orc_veteran", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
