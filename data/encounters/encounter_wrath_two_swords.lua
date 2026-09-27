-- TWO SWORDS: the Horn's teaching fight. Fell one oni and the other goes Horn Out at whoever did it; snap a horn
-- first, or fell both in one turn.
-- Approved 2026-09-27 ("The Oni of Wrath", round 2).
local Band = require("models.band")

return {
    name = "Two Swords",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_oni", "character_oni" }, ctx,
            "character_oni_student", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
