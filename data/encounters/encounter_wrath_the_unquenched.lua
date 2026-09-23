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
    -- WHICH of the two is `rung` below, and on an elite it is REQUIRED rather than optional: one elite,
    -- one floor. A biome lock places a body in the stratum and then leaves it standing on both of that
    -- stratum's stairs, which makes a landmark into traffic -- see models/encounter.lua's eligibility
    -- note for the whole argument, and tests/elite_floor_spec.lua for the count that holds it.
    --
    -- Descent.SINS' `elites` is the SEPARATE question of which of a floor's candidates the floor is
    -- ABOUT (billed at ELITE_NAMED_WEIGHT). The rung says where a thing may stand at all.
    condition = function(ctx) return ctx.biome == "volcanic" end,
    -- RUNG 1 -- the approach, which is where Wrath bills her.
    rung = 1,
    composition = function(ctx)
        local list = { "character_the_unquenched" }
        return Band.fill(list, ctx, "character_ember_spit", { base = 3, per = 6 })
    end,
}
