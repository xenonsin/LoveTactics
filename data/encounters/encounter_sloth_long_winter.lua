-- THE LONG WINTER, the apex of the Sloth circle.
--
-- It does not get stronger as it is cut; it sheds more drift-things, and a drift-thing takes turns. So
-- the escalation is a tempo escalation and the longer the fight runs the less of it is yours -- which is
-- the honest apex reading for a stratum that charges the clock rather than the body.
local Band = require("models.band")

return {
    name = "The Long Winter",
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
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_the_long_winter" }
        return Band.fill(list, ctx, "character_hollow_sleeper", { base = 1, per = 6 })
    end,
}
