-- THE FEN MOUTH: the Grendlemaw, with a screen in front of it.
--
-- ONE MAW, EVER. It swallows a body whole -- out of the fight in both directions until somebody cuts it
-- back out (data/items/weapon/weapon_grendlemaw_gullet.lua) -- and two of them could halve a company in
-- two turns with no interaction at all. So the composition names it once and thickens the screen
-- instead, which also makes the fight the right shape: the maw is slow and short-reached, and the
-- bogswallows exist to stop you simply walking away from it.
--
-- `elite`, so it opens at Arena.ELITE_CAP rather than the four-body skirmish ceiling. A set-piece that
-- opened at four would be the maw and two swallows, which is not a screen.
local Band = require("models.band")

return {
    name = "The Fen Mouth",
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
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_grendlemaw", "character_bogswallow" }
        return Band.fill(list, ctx, "character_bogswallow", { base = 2, per = 6 })
    end,
}
