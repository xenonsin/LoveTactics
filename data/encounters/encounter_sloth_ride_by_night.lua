-- RIDE BY NIGHT: the Yuki-onna makes the sleepers and the Mare rides them ("Sloth's Bestiary", 2026-10-04,
-- approved). Keep moving near the snow woman, and wake whoever went under before the Mare reaches them.
--
-- The review's ice is two; the band rolls around that centre (1-3) and is rated at two.
local Band = require("models.band")

return {
    name = "Ride by Night",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    -- RUNG 2: the seat, floor 10.
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_mare", "character_yuki_onna" }, ctx, "character_ice_elemental", { base = 2 })
    end,
}
