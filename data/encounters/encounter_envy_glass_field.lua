-- THE GLASS FIELD: the Envy circle's ordinary traffic, and the fight that takes rather than kills.
--
-- Neither body here can put you down quickly. What they do is strip -- one blessing a swing from the
-- motes, two from the eater -- so the party that walks out is the party that walked in, minus everything
-- it had spent turns setting up.
--
-- The reason that is not merely annoying is what stands behind it on the deeper stops: Lesser Reflection
-- copies the WEAKEST body it can see, and stripping is how a body becomes weakest. This fight decides
-- who Second Water takes.
local Band = require("models.band")

return {
    name = "The Glass Field",
    kind = "combat",
    weight = 5,
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
        local list = { "character_glass_eater" }
        return Band.fill(list, ctx, "character_glass_mote", { base = 3, per = 5 })
    end,
}
