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
    -- WHICH of the two is `rung` below, and on an elite it is REQUIRED rather than optional: one elite,
    -- one floor. A biome lock places a body in the stratum and then leaves it standing on both of that
    -- stratum's stairs, which makes a landmark into traffic -- see models/encounter.lua's eligibility
    -- note for the whole argument, and tests/elite_floor_spec.lua for the count that holds it.
    --
    -- Descent.SINS' `elites` is the SEPARATE question of which of a floor's candidates the floor is
    -- ABOUT (billed at ELITE_NAMED_WEIGHT). The rung says where a thing may stand at all.
    condition = function(ctx) return ctx.biome == "desert" end,
    -- RUNG 2 -- the seat, which is where Envy bills her -- and the heavier of the desert's two,
    -- measured.
    rung = 2,
    composition = function(ctx)
        local list = { "character_the_second_self", "character_mimic_of_ash" }
        return Band.fill(list, ctx, "character_glass_mote", { base = 2, per = 6 })
    end,
}
