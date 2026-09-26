-- THE MARCH: the drum is the whole fight, on Wrath's approach (approved as pitched, 2026-09-26, "The Orcs of Wrath").
-- Every other turn the line steps in at once; read the Drumbeat and step back, or kill the Drummer.
local Band = require("models.band")

return {
    name = "The March",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_orc_war_drummer", "character_orc_spear_hurler" }, ctx,
            "character_orc_grunt", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
