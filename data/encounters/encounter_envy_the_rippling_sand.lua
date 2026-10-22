-- THE RIPPLING SAND: a run of Sand-Eels with a Shade among them, approach traffic on the Ribstone Waste ("Envy's
-- Bestiary", rounds 1 and 3). Everything here is somewhere you cannot hit it -- under the sand or in the lee of the
-- rock -- and comes up for a turn at a time. Hit what is up.
--
-- THE OBJECTIVE (the objective pass, 2026-10-21): get across the dunes. Nothing here can be hit while it is under,
-- so the company crosses instead of waiting for things to come up.
local Band = require("models.band")

return {
    name = "The Rippling Sand",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_shade" }, ctx, "character_sand_eel", { base = 3, min = 2, max = 4 })
    end,
    objective = {
        type = "reach", region = "far", place = "across the dunes", enemy = "the eels",
        -- Eels only. Authored so the default tide does not deal a second Shade.
        waves = {
            { every = 12, from = "surround", maxAlive = 5, composition = { "character_sand_eel" } },
        },
    },
}
