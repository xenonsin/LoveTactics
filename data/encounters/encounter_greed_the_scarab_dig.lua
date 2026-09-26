local Band = require("models.band")

-- SCARABS IN THE DIG: two families going for the same heaps. The dwarves pocket the gold and sicken on it;
-- the scarabs roll it away from under them. Reviewed 2026-09-25 ("The Coin-Eaters").
return {
    name = "Scarabs in the Dig",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_dwarf_delver", "character_dwarf_delver" }, ctx,
            "character_gilded_scarab", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
