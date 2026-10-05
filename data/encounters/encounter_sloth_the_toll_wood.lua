-- THE TOLL WOOD: the Old Spruce, a Bailiff and Toll-Collectors, seat traffic on the tundra ("Sloth's Bestiary",
-- round 5, 2026-10-04; added at integration because its bodies came from two slices).
--
-- The lesson: the roots close the lanes while the Exit Fee punishes changing your mind. Burn the spruce early, or
-- fight in the space you chose.
local Band = require("models.band")

return {
    name = "The Toll Wood",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_old_spruce", "character_bailiff" }, ctx, "character_toll_collector",
            { base = 1, min = 1, max = 2 })
    end,
}
