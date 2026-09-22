-- THE GILT WYRM: the circle's dragon, on the pile it stopped being separable from.
--
-- A four-tile body on a warren carve is a door that closed, and this one takes coin off everything it
-- catches. The crawlers with it are the rest of the treasury, which means the fight is fought in a
-- corridor against something that does not need to move.
local Band = require("models.band")

return {
    name = "The Gilt Wyrm",
    kind = "elite",
    weight = 2,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_the_gilt_wyrm" }
        return Band.fill(list, ctx, "character_coffer_crawler", { base = 2, per = 6 })
    end,
}
