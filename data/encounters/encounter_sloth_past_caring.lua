-- PAST CARING: the Noonday Demon and three Bog Bodies, approach traffic on the tundra ("Sloth's Bestiary",
-- 2026-10-04, slice C). The two rules feed each other on purpose: a blow of 8 or less on a Bog Body deals no
-- damage, and the Demon counts it. Chip at the line beside it and the company is Listless; hit hard, or hit the
-- Demon.
--
-- PINNED, not banded (tests/encounter_spec.lua): three Bog Bodies is the review's count and the skirmish ceiling
-- with the Demon beside them, so a band could only roll the line thinner than the lesson needs.
local Band = require("models.band")

return {
    name = "Past Caring",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_noonday_demon" }, ctx, "character_bog_body", { base = 3, min = 3, max = 3 })
    end,
}
