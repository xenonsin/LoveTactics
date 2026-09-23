-- THE UNWANTED, and the apex encounter of the Envy circle.
--
-- A 2x2 body that answers being cut by coming apart: each threshold sheds a pair of glass-motes
-- (data/items/utility/utility_fracture_line.lua), so the health bar going down is not the whole story --
-- there is more of it on the board than there was.
--
-- Fielded with a thin opening escort on purpose. The fight is supposed to START small and grow, which is
-- the exact inverse of The Sated one stratum over, where the apex opens enormous and deflates. Two
-- circles, two opposite readings of what a big body does as you hurt it, and both of them true to
-- the sin they belong to.
local Band = require("models.band")

return {
    name = "The Unwanted",
    kind = "elite",
    weight = 1,
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
    -- RUNG 1 -- the approach, which is where Envy bills her.
    rung = 1,
    composition = function(ctx)
        local list = { "character_the_unwanted" }
        return Band.fill(list, ctx, "character_glass_eater", { base = 1, per = 6 })
    end,
}
