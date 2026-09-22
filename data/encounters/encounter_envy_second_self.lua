-- THE SECOND SELF, with the glass that decides what it copies.
--
-- The motes are not a screen here, they are the mechanism. Lesser Reflection takes the WEAKEST body it
-- can see, and the motes spend the fight stripping blessings to change which one that is -- so the
-- player's answer is the shape of their company rather than a target priority.
--
-- `elite`, so it opens at Arena.ELITE_CAP: at the four-body skirmish ceiling this would be the Second
-- Self and two motes, which is not enough glass for the choice to be real.
local Band = require("models.band")

return {
    name = "The Second Self",
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
    condition = function(ctx) return ctx.biome == "desert" end,
    composition = function(ctx)
        local list = { "character_the_second_self", "character_mimic_of_ash" }
        return Band.fill(list, ctx, "character_glass_mote", { base = 2, per = 6 })
    end,
}
