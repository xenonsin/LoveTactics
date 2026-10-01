-- THE DISPLAY: the Peacock-Basilisk shown off in front of Pride's gilded pages. Approved 2026-09-30 on Pride's
-- bestiary review.
--
-- The bird Stuns any foe within 3 that ends a turn without attacking it, and the pages are the rank that makes
-- attacking it awkward: every blow spent on the bird is a blow not spent on them, and a page in a closed rank
-- hits like a sworn (utility_rank_and_file).
local Band = require("models.band")

return {
    name = "The Display",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_peacock_basilisk" }, ctx, "character_gilded_page", { base = 2, per = 6, max = 3 })
    end,
}
