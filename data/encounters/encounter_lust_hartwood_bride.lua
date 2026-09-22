-- THE HARTWOOD BRIDE: where the Chorister takes one body out of your line, she takes a rank.
--
-- A four-tile body standing in an open trail is that trail closed, which in a circle built on breaking
-- formations means the ground you would have re-formed on has gone.
local Band = require("models.band")

return {
    name = "The Hartwood Bride",
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
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_the_hartwood_bride" }
        return Band.fill(list, ctx, "character_petal_drift", { base = 3, per = 6 })
    end,
}
