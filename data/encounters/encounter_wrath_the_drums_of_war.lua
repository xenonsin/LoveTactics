-- THE DRUMS OF WAR: on Wrath's seat (approved as pitched, 2026-09-26, "The Orcs of Wrath"). The March carries both
-- Berserkers into reach together, so stepping away from one streak puts you beside the other.
local Band = require("models.band")

return {
    name = "The Drums of War",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_orc_war_drummer", "character_orc_berserker", "character_orc_berserker" }, ctx,
            "character_orc_grunt", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
