local Band = require("models.band")

-- THE BROOD QUEEN: the Coin-Eaters' elite and floor five's puzzle -- keep her hoard under 20, or read the
-- marked lane in time (ability_roll_the_hoard). Runged onto the approach and billed as a spare
-- (Descent.SINS). Reviewed 2026-09-25 ("The Coin-Eaters").
return {
    name = "The Brood Queen",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_brood_queen" }, ctx, "character_gilded_scarab",
            { base = 3, min = 3, per = 6, max = 4 })
    end,
}
