-- THE HIGH GLADE: the Highwing and two wyverns in its wind. An elite rather than ordinary traffic because a
-- body that spends half the fight nearly impossible to hit is a long fight by construction -- a thing to
-- see on the map and decide about, never something that jumps a company in a corridor.
--
-- A RUNG-2 SPARE in Descent.SINS, beside the Sow and the Meandering Stag. The Sated stays the seat's named
-- elite; this is one more thing that might be standing on that floor.
--
-- HOLD THE CLEARING (the objective pass, 2026-10-21). A body that is hard to hit in the air is a long fight to
-- kill; a body that has to put its feet on the clearing to stop you holding it is a fight it has to come down
-- for.
local Band = require("models.band")

return {
    name = "The High Glade",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 2,
    composition = function(ctx)
        local list = { "character_the_highwing" }
        return Band.fill(list, ctx, "character_wyvern", { base = 2, min = 2, per = 10 })
    end,
    objective = { type = "hold", region = "center", duration = 30, enemy = "the Highwing" },
}
