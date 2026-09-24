-- THE MANY-FACED KING on the desert's seat floor (rung 2), over two of its own.
local Band = require("models.band")

return {
    name = "The Many-Faced King",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_many_faced_king" }, ctx, "character_mimic_slime", { base = 2, min = 2, per = 7 })
    end,
}
