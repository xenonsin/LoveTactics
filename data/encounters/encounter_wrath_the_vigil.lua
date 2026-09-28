-- THE VIGIL (Wrath, floor 7): two or three Asura Acolytes, and the rule taught cleanly. Three gauges on the board, and
-- the company learns which of them to leave alone -- a struck asura fills, an untouched one cools, and a full
-- one throws everything at whoever is nearest (models/asura.lua). Approved on review 2026-09-27/28.
local Band = require("models.band")

return {
    name = "The Vigil",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_asura_acolyte", "character_asura_acolyte" }, ctx,
            "character_asura_acolyte", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
