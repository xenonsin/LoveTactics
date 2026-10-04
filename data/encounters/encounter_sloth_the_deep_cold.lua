-- THE DEEP COLD: a Frost Worm and two or three Ice Elementals, seat traffic on the tundra ("Sloth's Bestiary",
-- 2026-10-04, slice C). The worm's own home ground: the elementals stand in the lanes a company would use to
-- finish it from 3 tiles away, and its death throes freeze whoever is closer, on either side.
local Band = require("models.band")

return {
    name = "The Deep Cold",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_frost_worm" }, ctx, "character_ice_elemental", { base = 2, min = 2, max = 3 })
    end,
}
