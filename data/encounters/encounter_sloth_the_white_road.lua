-- THE WHITE ROAD: Yuki-onna and two Yeti, approach traffic on the tundra ("Sloth's Bestiary", round 5, 2026-10-04;
-- added at integration because its bodies came from two slices).
--
-- The lesson is two rules that pull opposite ways: she puts the still to sleep and they root the lone, so the
-- company advances as a pair, every turn.
--
-- PINNED at the review's count (tests/encounter_spec.lua): two yeti, so there is always a roar on each flank.
local Band = require("models.band")

return {
    name = "The White Road",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_yuki_onna" }, ctx, "character_yeti", { base = 2, min = 2, max = 2 })
    end,
}
