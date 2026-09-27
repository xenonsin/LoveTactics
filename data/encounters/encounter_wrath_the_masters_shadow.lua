-- THE MASTER'S SHADOW: the Shadow's thread holds a body where the master's Instant Draw is waiting.
-- Approved 2026-09-27 ("The Oni of Wrath", round 2).
local Band = require("models.band")

return {
    name = "The Master's Shadow",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_oni_swordmaster", "character_oni_shadow" }, ctx,
            "character_oni_student", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
