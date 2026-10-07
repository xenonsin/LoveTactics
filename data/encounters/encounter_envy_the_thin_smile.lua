-- THE THIN SMILE: a pack of Wasting Ones, approach traffic on the Ribstone Waste ("Envy's Bestiary", round 4). Every
-- wound you take in their sight feeds them, so the lesson is not to be hurt where they can see: use the ridges, and
-- take them down before anything else.
local Band = require("models.band")

return {
    name = "The Thin Smile",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_wasting_one" }, ctx, "character_wasting_one", { base = 1, min = 1, max = 2 })
    end,
}
