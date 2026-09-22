-- THE DRIFT: the Lust circle's ordinary traffic, and its dilemma stated cheaply.
--
-- Drifts that Charm and are not worth a turn to kill; a wraith that will not stand still to be answered.
-- The fight is not a damage problem, it is a question about whether to spend -- which is exactly what the
-- deeper stops of this circle charge for.
local Band = require("models.band")

return {
    name = "The Drift",
    kind = "combat",
    weight = 5,
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
        local list = { "character_bloom_wraith" }
        return Band.fill(list, ctx, "character_petal_drift", { base = 3, per = 5 })
    end,
}
