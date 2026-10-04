-- THE SNOW QUEEN: Sloth's approach elite ("Sloth's Bestiary", 2026-10-04, approved). The Queen and her escort of ice
-- elementals; her splinter takes the company's healing away and her palace cuts the board into rooms. Fire answers
-- both.
--
-- The review's escort is two. The band rolls around that centre (1-3) like every rolled stop, and is rated at two.
local Band = require("models.band")

return {
    name = "The Snow Queen",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "tundra" end,
    -- RUNG 1: the approach, floor 9 (an elite's rung is an exact lock: models/encounter.lua).
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_snow_queen" }, ctx, "character_ice_elemental", { base = 2 })
    end,
}
