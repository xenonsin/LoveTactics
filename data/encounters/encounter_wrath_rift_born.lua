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
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_rift_born" }
        return Band.fill(list, ctx, "character_cinder_kin", { base = 1, per = 6 })
    end,
}
