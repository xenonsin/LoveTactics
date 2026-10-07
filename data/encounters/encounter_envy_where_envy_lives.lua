-- WHERE ENVY LIVES: the Pale Crone and her Wasting Ones, approach traffic on the Ribstone Waste ("Envy's Bestiary",
-- round 4). Both halves of the sin at once: getting hurt feeds the pack, and healing calls the Crone, so the company
-- heals out of her sight or baits her into its blades.
local Band = require("models.band")

return {
    name = "Where Envy Lives",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_pale_crone" }, ctx, "character_wasting_one", { base = 2, min = 2, max = 3 })
    end,
}
