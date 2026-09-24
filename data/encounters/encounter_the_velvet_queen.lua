-- THE VELVET QUEEN, on the keep's seat floor (rung 2), over two of her own.
--
-- The crowned version one floor under the slimes that teach the rule, as the fen's King sits one floor
-- under its ooze. KILLALL, for the King's reason: an `assassinate` would end the fight on the beat her
-- split begins it -- and her pieces are wearing the company's armour.
local Band = require("models.band")

return {
    name = "The Velvet Queen",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "castle" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_velvet_queen" }, ctx, "character_velvet_slime",
            { base = 2, min = 2, per = 7 })
    end,
}
