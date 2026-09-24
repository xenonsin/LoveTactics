-- A CAST OF HAWKS: three to five hawks and nothing else -- "cast" is the falconer's word for a group of
-- them. Reviewed 2026-09-23 ("The Sated and the Flight"): the fight where the Swoop and the Mantling are
-- met on their own, before a griffin or the Sated makes either one worse. Rung 1, home on the approach.
local Band = require("models.band")

return {
    name = "A Cast of Hawks",
    kind = "combat",
    weight = 2,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_hawk", { base = 3, min = 3, per = 4, max = 5 })
    end,
}
