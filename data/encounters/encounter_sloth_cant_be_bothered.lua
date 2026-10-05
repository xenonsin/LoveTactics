-- CAN'T BE BOTHERED: the Ogre and two Ground Sloths, approach traffic on the tundra ("Sloth's Bestiary", round 5,
-- 2026-10-04; added at integration because its bodies came from two slices).
--
-- The lesson is the two laziest things on the ice working together without meaning to: never stand beside the
-- ogre, because it throws you into a sloth's reach, and that sloth spends its whole bank on you.
--
-- PINNED at the review's count (tests/encounter_spec.lua): with one sloth the ogre has nobody worth throwing at.
local Band = require("models.band")

return {
    name = "Can't Be Bothered",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_sloth_ogre" }, ctx, "character_ground_sloth", { base = 2, min = 2, max = 2 })
    end,
}
