-- THE WEIR: a lamia out of the Cistern, with the Shoalkin standing in the water she coils you beside.
--
-- The first Lust fight that mixes the naga with a demon. The Cistern teaches that distance costs you
-- once the coils are on; here the Shoalkin hold the wet ground a company would retreat across, so the
-- lesson is tested rather than taught. HOLD: the lamia roots, and the Shoalkin do neither.
--
-- Approved on review 2026-09-25 (variety round 1, `l3_weir`).
local Band = require("models.band")

return {
    name = "The Weir",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_lamia" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 2, max = 2 })
    end,
}
