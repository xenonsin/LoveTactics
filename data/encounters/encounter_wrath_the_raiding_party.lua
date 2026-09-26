-- THE RAIDING PARTY: the orcs at their plainest, on Wrath's approach (approved as pitched, 2026-09-26, "The Orcs of
-- Wrath"). The Spear-Hurler drags someone in and the Berserker starts its streak on them; the Grunts finish what
-- falls, and every kill is a scar.
local Band = require("models.band")

return {
    name = "The Raiding Party",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_orc_berserker", "character_orc_spear_hurler" }, ctx,
            "character_orc_grunt", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
