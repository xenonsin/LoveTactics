-- EMBER NEWTS: the first thing the game ever teaches, met again as the wood's traffic (2026-10-21).
--
-- Act 0 opens on these -- "swing, and watch it fall" -- on floor one, and then the company walks floor
-- one for real and never sees another. A place that keeps its own animals is a place; one whose opening
-- bodies vanish the moment the lesson is over is a stage set. So the newts are part of the wood now,
-- fielded as the unpinned copy (character_ember_newt.lua says why the tutorial body cannot be).
--
-- WHAT IT ASKS is the spit: a clutch of fragile bodies that hurt from three tiles and die to a stroke.
-- The fight is closing the distance before the embers add up, which is the opposite read from the
-- wolves' (they close on you).
local Band = require("models.band")

return {
    name = "Ember Newts",
    kind = "combat",
    weight = 4,
    -- Locked to the wood and homed on its first floor, as every rung-1 beast is (encounter_boar.lua
    -- argues why there is no depth gate).
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    -- THREE OR FOUR. Chaff at fourteen health, so a clutch rather than a pair: at two they are one
    -- swing each and the fight is over before the spit has said anything.
    composition = function(ctx)
        return Band.fill({}, ctx, "character_ember_newt", { base = 3, min = 3, max = 4, per = 5 })
    end,
}
