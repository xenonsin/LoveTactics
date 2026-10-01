-- THE CHOIR: the angels' teaching fight. Heralds bless and a Virtue wards whoever bleeds most; nothing the company
-- lays on them lands. Kill the singers first, or spread the blows the Virtue answers.
-- Reviewed 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "The Choir",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2, -- the seat
    composition = function(ctx)
        return Band.fill({ "character_virtue", "character_herald" }, ctx,
            "character_herald", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
