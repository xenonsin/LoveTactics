-- THE LESSON: the master waits and cuts whoever walks in, and the Oni beside it crits the more for it.
-- Approved 2026-09-27 ("The Oni of Wrath", round 2).
local Band = require("models.band")

return {
    name = "The Lesson",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_oni_swordmaster", "character_oni" }, ctx,
            "character_oni_student", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
