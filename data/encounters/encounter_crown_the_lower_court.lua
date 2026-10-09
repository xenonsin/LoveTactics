-- THE LOWER COURT: a Greater Archon and two or three Lesser Archons, ordinary traffic on the Crown's floor ("The
-- Crown's Bestiary", slice A, 2026-10-09). The Archons' first sentence: stop the wisps while the rest fight, and learn
-- that plate does nothing against a Mana Edge.
--
-- NO `rung`, and that is not an oversight: the underworld is the single floor under all seven circles, so the ground
-- IS the pin (models/descent.lua's Descent.CROWN_ELITES says the same for the floor's elites).
local Band = require("models.band")

return {
    name = "The Lower Court",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        -- Two Lessers, and a third at the floor's own depth (it is only ever met on fifteen): 2-3, never 4.
        return Band.fill({ "character_greater_archon" }, ctx, "character_lesser_archon",
            { base = 2, per = 15, min = 2, max = 3 })
    end,
}
