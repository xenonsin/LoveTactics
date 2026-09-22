-- THE SLEEPERS: the fight that teaches Sworn.
--
-- The hollow sleeper swears two of your company together when it acts, and the drift-things Halt -- so a
-- Halted body that is also Sworn drags its partner's tempo down with it. One lost turn costs two, which
-- is the circle's whole combo and is Acedia's opening announcement, met two bodies at a time.
local Band = require("models.band")

return {
    name = "The Sleepers",
    kind = "combat",
    weight = 4,
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
        local list = { "character_hollow_sleeper", "character_drift_thing" }
        return Band.fill(list, ctx, "character_rime_gnat", { base = 1, per = 6 })
    end,
}
