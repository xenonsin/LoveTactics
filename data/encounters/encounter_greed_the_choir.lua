-- THE CHOIR: a Scale-Priest, a Broodkeeper, an egg and Skulkers. Approved 2026-09-24/25. The priest's
-- Borrowed Breath is +3 for every kobold beside it, so the huddle round it IS the threat -- break it up
-- before it breathes. The egg keeps the pack close (the Dragon's Eye, three tiles out), and Dragon's Call
-- steps the whole line toward it once a fight.
--
-- HOMED ON THE SEAT (rung 2).
local Band = require("models.band")

return {
    name = "The Choir",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_kobold_scale_priest", "character_kobold_broodkeeper", "character_dragon_egg" },
            ctx, "character_kobold_skulker", { base = 1, per = 6, max = 2 })
    end,
}
