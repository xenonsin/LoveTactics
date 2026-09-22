-- THE SATED, and the apex encounter of the Gluttony circle.
--
-- A 2x2 body on a mire board is a door closed across the only dry line -- it blocks four tiles, is
-- struck from beside any of them, eats an area blast once rather than four times, and slides as one when
-- knocked back. The flies around it are not a screen so much as a supply: they are what it has been
-- eating, and they are still arriving.
--
-- The fight's shape is the inverse of every other set-piece in the descent. The Sated opens at the top
-- of its band and gets WEAKER at each threshold (data/items/utility/utility_distended_hide.lua), so a
-- party that commits everything into the first two turns is rewarded rather than punished. That is a
-- true thing about an appetite that has already been satisfied, and it is the deliberate opposite of
-- what Wrath's circle teaches one stratum over.
local Band = require("models.band")

return {
    name = "The Sated",
    kind = "elite",
    weight = 1, -- rarest thing on the floor: the body a stratum is remembered for
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_the_sated" }
        -- THE FLIES ARE DELETED (2026-09-22) and the hawk is the nearest thing the wood still has.
        -- The supply reading above is what the replacement owes back: this is a body that carries
        -- no Engorge and is not what the Sated has been eating.
        return Band.fill(list, ctx, "character_hawk", { base = 2, per = 4 })
    end,
}
