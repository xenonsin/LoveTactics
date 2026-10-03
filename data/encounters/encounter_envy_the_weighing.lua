-- THE WEIGHING: a court of Jackal Weighers, approach traffic on the Ribstone Waste ("Envy's Bestiary", round 2).
-- Each turn the scale names a heavier heart and every Weigher goes for it, so the company's own health bars are the
-- board: keep them level, and the scale keeps changing its mind.
local Band = require("models.band")

return {
    name = "The Weighing",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_jackal_weigher", { base = 3, min = 2, max = 3 })
    end,
}
