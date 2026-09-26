-- THE MERE: the Tidecaller on the approach, before the Undertow leans on it.
--
-- Until this fight the Tidecaller was met only inside the Undertow, a seat elite, so its verb arrived at
-- full strength the first time anybody saw it. Two Shoalkin beside it here, and the verb is learnt a floor
-- early. EITHER half: nobody in it roots or shoves.
--
-- It shares the Tidecaller with the seat's Tide Pool on purpose -- both were approved (variety round 1,
-- `l3_mere` and `l4_tidepool`, 2026-09-25); this is the light meeting and that one the whole faction.
local Band = require("models.band")

return {
    name = "The Mere",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_tidecaller" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 2, max = 2 })
    end,
}
