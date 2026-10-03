-- THE RIPPLING SAND: a run of Sand-Eels with a Shade among them, approach traffic on the Ribstone Waste ("Envy's
-- Bestiary", rounds 1 and 3). Everything here is somewhere you cannot hit it -- under the sand or in the lee of the
-- rock -- and comes up for a turn at a time. Hit what is up.
local Band = require("models.band")

return {
    name = "The Rippling Sand",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_shade" }, ctx, "character_sand_eel", { base = 3, min = 2, max = 4 })
    end,
}
