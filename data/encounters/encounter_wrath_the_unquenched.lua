-- THE UNQUENCHED, with the swarm that feeds it.
--
-- The ember-spits are not a screen -- they are the drake's supply line. Each one you kill leaves fire,
-- and the Unquenched heals as it acts while standing in fire
-- (data/traits/trait_drinks_the_fire.lua). So the obvious opening (clear the little ones) is the losing
-- one, and the fight is about making the drake come to you across ground nothing has died on.
--
-- `elite`, so it opens at Arena.ELITE_CAP: at the four-body skirmish ceiling this would be the drake and
-- two spits, which is not enough fire for the trap to be real.
local Band = require("models.band")

return {
    name = "The Unquenched",
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
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_the_unquenched" }
        return Band.fill(list, ctx, "character_ember_spit", { base = 3, per = 6 })
    end,
}
