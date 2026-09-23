-- RIFT-BORN, the apex of the Wrath circle.
--
-- It does not grow as it is cut; it makes the room smaller. Every threshold sheds a pair of ember-spits
-- (data/items/utility/utility_riftline.lua) and every spit leaves fire where it falls, so a long fight
-- ends on a board that has mostly caught alight.
--
-- The deliberate inverse of the Sated, one stratum over, which opens enormous and deflates. Two apexes,
-- two opposite readings of what a big body does as you hurt it, each true to its own sin.
local Band = require("models.band")

return {
    name = "Rift-Born",
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
    condition = function(ctx) return ctx.biome == "volcanic" end,
    -- RUNG 2 -- the seat, which is where Wrath bills it.
    rung = 2,
    composition = function(ctx)
        local list = { "character_rift_born" }
        return Band.fill(list, ctx, "character_cinder_kin", { base = 1, per = 6 })
    end,
}
