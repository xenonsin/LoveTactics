-- POPPY FIELDS: a cloud of Poppy-Moths and the Mare, seat traffic on the tundra ("Sloth's Bestiary", round 5,
-- 2026-10-04; added at integration because its bodies came from two slices).
--
-- The lesson: kill the moths from range and wake your own fast, because every sleeper you leave down is a body the
-- Mare can ride. The approved cloud is 4-6; like the Sleeping Wood it opens the skirmish cap to fit the cloud.
local Band = require("models.band")

return {
    name = "Poppy Fields",
    kind = "combat",
    weight = 3,
    enemyCap = 5,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_mare" }, ctx, "character_poppy_moth", { base = 4, min = 3, max = 4 })
    end,
}
