-- THE COLOURS: the fight that teaches "kill the one that is not hitting you".
--
-- The standard-bearer holds the rank together and barely fights. Killing it does not merely stop a buff:
-- because the rank rule is measured live off adjacency, the shape collapses and the survivors become
-- ordinary. It is where the game teaches killing the body that is not hitting you -- a job the Long
-- Note held until the human companies were deleted, and this fight now holds alone.
local Band = require("models.band")

return {
    name = "The Colours",
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
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_standard_bearer", "character_gilded_sworn" }
        return Band.fill(list, ctx, "character_gilded_page", { base = 1, per = 6 })
    end,
}
