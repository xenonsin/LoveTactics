-- THE LARDER: the Larder Mother and her Giant Spiders -- the densest web in the game (six strands of
-- hers, three per spider, plus the wood's own) laid across the glade before the bell. An elite of the
-- approach floor (rung 1), billed as a spare beside the Unseeing in Descent.SINS: the White Wolf stays
-- the floor's named exam, and this is the other thing that might be waiting on it.
--
-- She opens with two escorts and fields more as the fight goes (Egg Sac, and the burst at half health),
-- so the opening roster rates her the way Muster rates every summoner: by what stands at the bell.
local Band = require("models.band")

return {
    name = "The Larder",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1,
    composition = function(ctx)
        local list = { "character_the_larder_mother" }
        return Band.fill(list, ctx, "character_giant_spider", { base = 2, min = 2, per = 8 })
    end,
}
