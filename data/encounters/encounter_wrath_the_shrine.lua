-- THE SHRINE: she keeps the Oni's horn whole and washes off what the company lays on it. Reach her first.
-- Approved 2026-09-27 ("The Oni of Wrath", round 2).
local Band = require("models.band")

return {
    name = "The Shrine",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_oni_priestess", "character_oni" }, ctx,
            "character_oni_student", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
