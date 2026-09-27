-- THE SIRE'S BROOD: the vampires' alpha fight, an elite on Wrath's approach (Wrath's vampires, 2026-09-26). The
-- Sire, two Fledglings, a Hemomancer and bats. While the Sire stands its Blood Bond holds the brood out of
-- Bloodlust and every drink they take tithes it; Call the Blood hauls every bleeding foe toward it. Kill it first
-- and the whole brood is in Bloodlust at once, biting the nearest body -- its own bats included.
--
-- ITS OWN CEILING OF EIGHT (agent invention, 2026-09-26): the page gives the bats "base 2, +1 per 6 levels, max 4"
-- beside four named bodies, which the elite tier's six would cut to two bats every time. `enemyCap = 8` lets the
-- band the review wrote be the band the board seats.
local Band = require("models.band")

return {
    name = "The Sire's Brood",
    kind = "elite",
    weight = 1,
    enemyCap = 8,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_the_sire", "character_fledgling", "character_fledgling", "character_hemomancer" },
            ctx, "character_familiar", { base = 2, min = 2, per = 6, max = 4 })
    end,
}
