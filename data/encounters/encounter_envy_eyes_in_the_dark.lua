-- EYES IN THE DARK: an Evil Eye watching over a pair of Shades, seat traffic on the Ribstone Waste ("Envy's
-- Bestiary", round 1). Both bodies are drawn for both of Envy's floors; this is the fight that stands them on the
-- seat in their own right rather than as strays off the approach. The Shades hide against the ridges the company
-- would hide its Fairest behind, so the eye's answer and the Shades' answer pull the company two ways.
local Band = require("models.band")

return {
    name = "Eyes in the Dark",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_evil_eye" }, ctx, "character_shade", { base = 2, min = 2, max = 3 })
    end,
}
