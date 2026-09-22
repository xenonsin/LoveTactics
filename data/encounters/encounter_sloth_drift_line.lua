-- THE DRIFT LINE: the Sloth circle's ordinary traffic.
--
-- Everything here costs turns rather than health -- Freeze from the gnats, Halted from the drift. On the
-- one board where crossing is free (data/biomes/tundra.lua), that is the only tax a stratum can levy,
-- and this is it at the cheapest rung.
local Band = require("models.band")

return {
    name = "The Drift Line",
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
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_drift_thing" }
        return Band.fill(list, ctx, "character_rime_gnat", { base = 3, per = 5 })
    end,
}
