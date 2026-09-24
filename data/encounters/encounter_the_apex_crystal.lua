-- THE APEX CRYSTAL on the spire's seat floor (rung 2), over the order it sits on.
local Band = require("models.band")

return {
    name = "The Apex Crystal",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_apex_crystal" }, ctx, "character_crystal_slime", { base = 2, min = 2, per = 7 })
    end,
}
