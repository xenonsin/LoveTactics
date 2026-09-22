-- THE BELOVED, the apex of the Lust circle -- and the one whose escalation is on your DECISION.
--
-- Every threshold sheds more drifts, and every drift is one more argument for holding your good ability.
-- Holding it is what this stratum charges for. So the fight does not get harder so much as the choice
-- gets worse, which is the most Lust thing an apex could do.
local Band = require("models.band")

return {
    name = "The Beloved",
    kind = "elite",
    weight = 1,
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
        local list = { "character_the_beloved", "character_chorister" }
        return Band.fill(list, ctx, "character_bloom_wraith", { base = 1, per = 6 })
    end,
}
