-- THE CHOIR: the fight that takes your formation apart.
--
-- The chorister Charms as it acts, so a body is pulled out of line and into cover where the wraiths are
-- waiting. Every other circle's control costs you a turn; this one costs you the shape of your company.
local Band = require("models.band")

return {
    name = "The Choir",
    kind = "combat",
    weight = 4,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_chorister", "character_bloom_wraith" }
        return Band.fill(list, ctx, "character_petal_drift", { base = 1, per = 6 })
    end,
}
