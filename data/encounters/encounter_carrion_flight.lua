-- CARRION FLIGHT: birds that will not commit, and the thing waiting underneath them for somebody to
-- stop moving.
--
-- The hawks harass and never trade; the crawler is what the harassment is FOR. A party that lets a body
-- go down while it is busy swatting at range discovers that the countdown had a second interested
-- party (data/characters/character_carrion_crawler.lua).
--
-- Punishes a company with no reach, which is a real build question and one nothing on the road asks
-- often enough.
local Band = require("models.band")

return {
    name = "Carrion Flight",
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
    -- LOCKED TO THE WOOD, which is the circle-lock rule arriving rather than a retune: humans
    -- float to every floor and everything else belongs to exactly one circle. This was shared
    -- road stock on all fifteen, and the beast band is Gluttony's identity now.
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_carrion_crawler" }
        return Band.fill(list, ctx, "character_hawk", { base = 3, per = 5 })
    end,
}
