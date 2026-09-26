-- THE COILWATER: the seat's second hold fight, heavier in coils than the Cistern.
--
-- An Elder Lamia and her daughter, with a Shoalkin in the water. The Elder leads the approach's billed
-- elite (the Drowned Stair), so meeting her in ordinary traffic a floor down cheapens that elite a little --
-- flagged on review and approved anyway (variety round 1, `l4_coilwater`, 2026-09-25). HOLD: both lamiae
-- root.
local Band = require("models.band")

return {
    name = "The Coilwater",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_elder_lamia", "character_lamia" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 1, per = 7, max = 2 })
    end,
}
