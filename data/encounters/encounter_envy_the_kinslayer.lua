-- THE KINSLAYER: Envy's seat-floor elite (reviewed 2026-10-01..03, "Envy's Bestiary", row kn_body). He hunts the
-- body of the company healed or blessed most this fight, and whoever fells him takes 7 times his last hit
-- (models/kinslayer.lua).
--
-- FIELDED OVER A BAND OF GLASS-MOTES, the circle's weather: they strip blessings, which takes nothing off the
-- favour count (it counts what LANDED this fight) but costs the company the blessing all the same -- so a company
-- that answers him by blessing someone else pays twice.
--
-- THE OBJECTIVE (the objective pass, 2026-10-21): kill the Kinslayer. This was an explicit killAll and the pass
-- reverses it: the motes are weather, and the fight is him.
local Band = require("models.band")

return {
    name = "The Kinslayer",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "desert" end,
    -- RUNG 2: the seat, floor 12 (an elite's rung is an exact lock: models/encounter.lua).
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_kinslayer" }, ctx, "character_glass_mote", { base = 1, per = 6 })
    end,
    objective = { type = "assassinate", target = "character_the_kinslayer", enemy = "the Kinslayer" },
}
