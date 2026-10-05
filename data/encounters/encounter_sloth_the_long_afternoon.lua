-- THE LONG AFTERNOON: the Noonday Demon, a Troll Scarlord and a Troll, approach traffic on the tundra ("Sloth's
-- Bestiary", round 5, 2026-10-04; added at integration because its bodies came from two slices).
--
-- The lesson is that support has nowhere to hide: the Scarlord wastes your heals and the demon punishes any turn
-- that dealt no damage, so the healer has to fight too.
--
-- PINNED at the review's count (tests/encounter_spec.lua): three bodies, two of them rules; a second troll would
-- make it a troll fight with a demon in it.
local Band = require("models.band")

return {
    name = "The Long Afternoon",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_noonday_demon", "character_troll_scarlord" }, ctx, "character_troll",
            { base = 1, min = 1, max = 1 })
    end,
}
