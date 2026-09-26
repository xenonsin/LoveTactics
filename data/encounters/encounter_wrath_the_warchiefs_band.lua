-- THE WARCHIEF'S BAND: the orcs' elite, on Wrath's seat beside the Goblin King (approved as pitched, 2026-09-26, "The
-- Orcs of Wrath"; Keno made the Warchief the elite). Kill the Warchief and the most-Proven orc takes his place;
-- the Blood-Caller hands out Proven without kills, so there is always an heir.
local Band = require("models.band")

return {
    name = "The Warchief's Band",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_orc_warchief", "character_orc_berserker", "character_orc_blood_caller" }, ctx,
            "character_orc_grunt", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
