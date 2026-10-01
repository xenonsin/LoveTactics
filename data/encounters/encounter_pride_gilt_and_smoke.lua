-- GILT AND SMOKE: an Ifrit behind a rank of gilded pages (reviewed 2026-09-30, "Pride's Bestiary"; the mixed fight
-- the review asked for, with Pride's own pages where an elf retainer was not yet in the tree). The pages want
-- the company close and in a doorway; the Ifrit wants it walking, because every tile walked on a Fire Trail
-- burns. Break the rank and the Ifrit has nowhere left to stand that is not beside somebody.
--
-- HOMED ON THE APPROACH (rung 1).
local Band = require("models.band")

return {
    name = "Gilt and Smoke",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_ifrit" }, ctx, "character_gilded_page", { base = 2, per = 6, max = 3 })
    end,
}
