-- THE EYRIE: the Lust circle's standing threat, and the fight that takes the choice away.
--
-- The Open Roof asks where you are willing to stand (data/encounters/encounter_lust_the_open_roof.lua).
-- This answers: nowhere, for long. The Matriarch's cry hauls a body the length of the hall to her and
-- lights it; her wing-beat throws everything adjacent off her the instant she is struck; the flock
-- around her spends its turns shoving whoever was coming to help. The company does not get to pick the
-- ground, so what it has to pick instead is which of those two rules it is going to answer -- close and
-- eat the Downdraft every swing, or hold the reach and spend the fight walking back out of the pull.
--
-- HER FLOCK IS THE SAME BIRD, ON PURPOSE. A player who has fought the Open Roof already knows exactly
-- what the small ones do; everything new on this board is hers, and the escalation is legible without
-- a word of explanation. The two blueprints are one lesson taught twice, which is what an approach and
-- a seat are for.
--
-- Locked to Lust's stratum by ctx.biome (the fen since the 2026-09-25 swap), the same gate every circle uses; billed on the circle's
-- own floors through Descent.SINS' `elites`, which is where a circle says WHICH of its two stairs a
-- threat stands on.
local Band = require("models.band")

return {
    name = "The Eyrie",
    kind = "elite",
    weight = 1, -- rarest thing on the floor: the body a stratum is remembered for
    condition = function(ctx) return ctx.biome == "swamp" end,
    -- RUNG 2 -- the seat, which is where Lust bills it. A party that learned on the stair that
    -- distance costs arrives here about to be compelled to cross a room.
    -- One elite, one floor: see models/encounter.lua's eligibility note.
    rung = 2,
    composition = function(ctx)
        local list = { "character_harpy_matriarch" }
        return Band.fill(list, ctx, "character_harpy", { base = 2, per = 5 })
    end,
}
