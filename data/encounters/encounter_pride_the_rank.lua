-- THE RANK: the Pride circle's ordinary traffic, and the lesson stated cheaply.
--
-- Nothing here is individually frightening. Both halves of the formation rule read adjacency LIVE, so a
-- closed rank is armoured and hitting properly, and the same bodies pulled through a doorway are four
-- suits of armour with opinions. The castle's `rooms` carve is what makes that a puzzle rather than a
-- number.
local Band = require("models.band")

return {
    name = "The Rank",
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
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_gilded_sworn" }
        return Band.fill(list, ctx, "character_gilded_page", { base = 3, per = 5 })
    end,
}
