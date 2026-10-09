-- THE KENNELS: the Crown's hound pack ("The Crown's Bestiary", slice C, approved 2026-10-09). Two or three Hellhounds,
-- and the lesson is to deny them the ground: every breath lays fire, every hound standing in it heals and bites
-- harder, so the fight is won by dousing it, soaking the hounds, or dragging them off it (trait_hearth_born).
--
-- NO `rung`, AND THAT IS NOT AN OVERSIGHT: the underworld is the single floor under all seven circles, so the ground
-- is the pin (models/descent.lua's Descent.CROWN_ELITES says the same for the floor's elites).
local Band = require("models.band")

return {
    name = "The Kennels",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_hellhound", { base = 2, min = 2, max = 3 })
    end,
}
