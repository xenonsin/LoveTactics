-- THE BLOOD OFFERING: the seat floor's step up (approved as pitched, 2026-09-26, "The Orcs of Wrath"). The Blood-
-- Caller pays its own blood to heal a Berserker and make it Proven without a kill, so a streak opens scarred.
local Band = require("models.band")

return {
    name = "The Blood Offering",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_orc_blood_caller", "character_orc_berserker", "character_orc_berserker" }, ctx,
            "character_orc_grunt", { base = 1, min = 0, per = 6, max = 2 })
    end,
}
