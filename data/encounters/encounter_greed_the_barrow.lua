local Band = require("models.band")

-- THE BARROW: two barrow-wights and the kobold dead in front of them. The light fight -- the wights come
-- through the walls, and swords pass through half of them unless somebody brings a flare or a spell.
-- Reviewed 2026-09-25 ("The Dead Hand").
return {
    name = "The Barrow",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_barrow_wight", "character_barrow_wight" }, ctx, "character_kobold_skeleton",
            { base = 2, min = 2, per = 8, max = 3 })
    end,
}
