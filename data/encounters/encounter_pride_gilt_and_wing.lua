-- GILT AND WING: the spire's two ranks on one floor. A Seraph and a Herald stand with the gilded -- the Sworn and its
-- Pages, armoured while they hold formation -- and the Hymn blesses only the angels. Break the rank, and do not end
-- a turn beside the fire. Reviewed 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "Gilt and Wing",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2, -- the seat
    composition = function(ctx)
        return Band.fill({ "character_seraph", "character_herald", "character_gilded_sworn" }, ctx,
            "character_gilded_page", { base = 1, min = 0, per = 6, max = 1 })
    end,
}
