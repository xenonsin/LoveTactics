-- THE FONT: one velvet slime in ordinary traffic, with the Shoalkin in the water round it.
--
-- Gluttony keeps its moss slimes as ordinary fights and saves the king for an elite; this gives Lust the
-- same shape. The Velvet Slimes are still this floor's elite spare, and a single one here spends some of
-- that elite's surprise -- flagged on review and approved anyway (variety round 1, `l3_font`,
-- 2026-09-25). EITHER half: neither body roots or shoves.
local Band = require("models.band")

return {
    name = "The Font",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_velvet_slime" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 2, max = 2 })
    end,
}
