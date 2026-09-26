-- THE MANDRAKE BED: the seat's own hold fight, and the Pit Garth grown up.
--
-- Until this fight every root on floor four was a stray from floor three: the seat's home fights were
-- all move or either. Two Alraune means two honey gardens and a company that cannot step off both, and
-- twice the Mandrakes means twice the screaming. HOLD: nothing here shoves.
--
-- Approved on review 2026-09-25 (variety round 1, `l4_mandrake_bed`).
local Band = require("models.band")

return {
    name = "The Mandrake Bed",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_alraune", "character_alraune" }
        return Band.fill(list, ctx, "character_mandrake", { base = 2, max = 2 })
    end,
}
