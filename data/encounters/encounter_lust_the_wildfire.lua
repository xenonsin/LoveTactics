-- THE WILDFIRE: the elementals as one fight, with the wind carrying the fire.
--
-- A Whirl, a Wind and a Fire Elemental. The Whirl leads the approach's Flue elite and the Lamp Room is
-- already the seat's fire fight, both flagged on review and approved anyway (variety round 1,
-- `l4_wildfire`, 2026-09-25). MOVE: the winds throw. The fire is what rolls: one flame or two.
local Band = require("models.band")

return {
    name = "The Wildfire",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_whirl_elemental", "character_wind_elemental" }
        return Band.fill(list, ctx, "character_fire_elemental", { base = 1, per = 8, max = 2 })
    end,
}
