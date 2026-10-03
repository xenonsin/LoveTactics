-- THE PATCHWORK: the sewn body and a drift of Glass-Motes, approach traffic on the Ribstone Waste ("Envy's
-- Bestiary", round 1). The motes are cheap to kill and they strip blessings; the Patchwork is slow to kill and it
-- sews whoever does the work to itself. Spread the blows, or burn it from a distance.
local Band = require("models.band")

return {
    name = "The Patchwork",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_patchwork" }, ctx, "character_glass_mote", { base = 2, min = 2, max = 3 })
    end,
}
