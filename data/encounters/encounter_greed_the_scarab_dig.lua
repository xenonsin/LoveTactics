local Band = require("models.band")

-- SCARABS IN THE DIG: two families going for the same heaps. The dwarves pocket the gold and sicken on it;
-- the scarabs roll it away from under them. Reviewed 2026-09-25 ("The Coin-Eaters").
--
-- HEAPS, on the objective pass (2026-10-21): the company is the third family at the gold, and three heaps
-- carried out wins it. Three more are scattered on top of the cave's own two to four, because two crews are
-- taking them off the board from the first turn.
return {
    name = "Scarabs in the Dig",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    scatter = { { id = "hazard_coin_heap", count = 3 } },
    composition = function(ctx)
        return Band.fill({ "character_dwarf_delver", "character_dwarf_delver" }, ctx,
            "character_gilded_scarab", { base = 2, min = 2, per = 6, max = 3 })
    end,
    objective = { type = "heaps", count = 3, enemy = "the diggers" },
}
