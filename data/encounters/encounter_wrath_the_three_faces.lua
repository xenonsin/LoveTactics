-- THE THREE FACES (Wrath, floor 8): a Three-Faced Asura and an Adept -- two bodies that spend on purpose, so
-- there are no free Bursts to wait out. The Three-Faced answers first (Keen Senses) with every arm.
local Band = require("models.band")

return {
    name = "The Three Faces",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_asura_three_faced", "character_asura_adept" }, ctx,
            "character_asura_adept", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
