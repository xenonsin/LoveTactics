-- THE GREY SHORE: the Crown's ordinary traffic, and the stop that teaches sustain under pressure. Approved
-- 2026-10-09 ("The Crown's Bestiary", slice E).
--
-- One Lethe-Drinker and the Hungry Ghosts that crowd round it. The ghosts eat any heal that lands within 2 of
-- them, and the Drinker's haze stops a body near it using the same ability two turns running -- so the company's
-- reflex answer to a hurt body (the same heal again) is refused twice over, and what it is left with is
-- position: heal away from the ghosts, pull the wounded back out of the haze, or kill the Drinker first.
--
-- THE GROUND IT WANTS is Lethe Shallows, the underworld's signature hazard, which another slice builds. This file
-- names it here and nowhere else: when the shallows land, the board is where they belong, not this composition.
--
-- AND NO `rung` EITHER, WHICH IS THE ONE PLACE THAT IS NOT AN OVERSIGHT: the bottom floor sits under all seven
-- circles and has no approach or seat, so the ground is the pin (encounter_the_bone_orchard.lua's header).
--
-- Three bodies at most, under the ordinary ceiling of four: the second ghost arrives as the road goes on.
local Band = require("models.band")

return {
    name = "The Grey Shore",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return Band.fill({ "character_lethe_drinker" }, ctx,
            "character_hungry_ghost", { base = 1, max = 2 })
    end,
}
