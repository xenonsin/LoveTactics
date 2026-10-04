-- THE TRILL: a Frost Worm with two Bog Bodies holding the lanes, approach traffic on the tundra ("Sloth's
-- Bestiary", 2026-10-04, slice C). The ring says where not to be when it lands, and the Bog Bodies are what make
-- leaving it dear: a body that started its turn beside one pays the Mire's toll to walk out of the ring.
--
-- PINNED, not banded (tests/encounter_spec.lua): two Bog Bodies is the review's count -- one per lane -- and the
-- ring of 4 already covers most of a board a third body would crowd.
local Band = require("models.band")

return {
    name = "The Trill",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_frost_worm" }, ctx, "character_bog_body", { base = 2, min = 2, max = 2 })
    end,
}
