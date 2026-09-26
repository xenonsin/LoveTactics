-- THE ROOKERY: a Harpy and the Nymphs that light her targets.
--
-- The Nymph's Mistlight makes the next shove go a tile further, and the Harpy is the shove. This is the
-- pairing the seat's Rood Loft is built on, taught without the Dryad's hedges -- which is also the
-- overlap, flagged on review and approved anyway (variety round 1, `l3_rookery`, 2026-09-25). MOVE:
-- nothing here roots.
local Band = require("models.band")

return {
    name = "The Rookery",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_harpy" }
        return Band.fill(list, ctx, "character_nymph", { base = 2, max = 2 })
    end,
}
