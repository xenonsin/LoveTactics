-- THE WINTER HART: an animal that makes the ground worse by walking on it.
--
-- It lays black ice as it acts, and the gnats around it keep you from simply walking away from where the
-- ice is going. What the fight asks is which of the two you would rather let happen -- the Hart moving,
-- or the Hart swinging -- because it pays for the ground with its turn.
local Band = require("models.band")

return {
    name = "The Winter Hart",
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
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_the_winter_hart" }
        return Band.fill(list, ctx, "character_rime_gnat", { base = 3, per = 6 })
    end,
}
