-- SMOKE AND GALE: the djinn's teaching fight (reviewed 2026-09-30, "Pride's Bestiary"). The Ifrit lays a Fire
-- Trail on a body and the Djinni's gale pushes it two tiles through its own fire. Neither will let you stand next
-- to it -- so the lesson is the room: back one into a corner and it does nothing at all.
--
-- HOMED ON THE APPROACH (rung 1).
local Band = require("models.band")

return {
    name = "Smoke and Gale",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_ifrit", "character_djinni" }, ctx,
            "character_gilded_page", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
