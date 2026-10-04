-- GLACIER GRAZERS: two Ground Sloths and a yeti or two, approach traffic on the tundra ("Sloth's Bestiary", slice
-- A, 2026-10-04).
--
-- The lesson is the two lines' rules set against each other: drain the sloths' banks from range, but the yeti root
-- anyone who goes out alone to do it.
local Band = require("models.band")

return {
    name = "Glacier Grazers",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_ground_sloth", "character_ground_sloth" }, ctx, "character_yeti",
            { base = 1, min = 1, max = 2 })
    end,
}
