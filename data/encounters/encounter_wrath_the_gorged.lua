-- THE GORGED: an elite on Wrath's seat floor (Wrath's vampires, reviewed 2026-09-26/27). The Gorged, two Fledglings
-- and bats. Every wound on the big one spills a pool the Fledglings drink from and the company bleeds in; at half it
-- bursts, floods the ground round it and comes at the nearest body, whoever's it is, until it falls.
--
-- Six at most, the elite tier's own ceiling: the Gorged, two Fledglings and two or three Familiars.
local Band = require("models.band")

return {
    name = "The Gorged",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_gorged", "character_fledgling", "character_fledgling" },
            ctx, "character_familiar", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
