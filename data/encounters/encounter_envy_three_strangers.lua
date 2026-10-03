-- THREE STRANGERS: the Faceless line soldiers in their threes. Three hands are nine possible bodies, and by the
-- second turn the squad is whatever answers the company best; kill the one already wearing its worst face for you.
-- Approved 2026-10-02 ("Envy's Bestiary", round 2).
local Band = require("models.band")

return {
    name = "Three Strangers",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_faceless", "character_faceless", "character_faceless" }, ctx,
            "character_faceless", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
