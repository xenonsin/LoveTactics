-- THE GLACIER KING on the tundra's seat floor (rung 2), over a rime and a frost slime.
local Band = require("models.band")

return {
    name = "The Glacier King",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_glacier_king", "character_frost_slime" }, ctx, "character_rime_slime",
            { base = 1, min = 1, per = 7, max = 2 })
    end,
}
