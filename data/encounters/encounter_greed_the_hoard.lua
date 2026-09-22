-- THE HOARD, the apex of the Greed circle -- and a fight with a clock made of its own reward.
--
-- It does not chase. Every threshold you cut it past sheds a pair of chitters that run for the dark
-- carrying as much as they can hold, so the pile is worth more the faster you get through it and being
-- careful costs you the thing you were being careful about.
--
-- The sharpest reading of the sin available, and the reason this is the apex rather than the Wyrm.
local Band = require("models.band")

return {
    name = "The Hoard",
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
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_the_hoard" }
        return Band.fill(list, ctx, "character_coin_chitter", { base = 2, per = 6 })
    end,
}
