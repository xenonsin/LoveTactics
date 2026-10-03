-- TWO FACES: the Colossus and the Doppelganger (reviewed 2026-10-01..03, "Envy's Bestiary"). One heap wearing two
-- bodies' kits, and one body wearing yours -- whichever of the company stands nearest it at the bell. Deploy with
-- the copy in mind, and bring two answers for the heap.
--
-- HOMED ON THE SEAT (rung 2).
local Band = require("models.band")

return {
    name = "Two Faces",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_faceless_colossus", "character_doppelganger" }, ctx,
            "character_mirror_knight", { base = 0, min = 0, per = 7, max = 1 })
    end,
}
