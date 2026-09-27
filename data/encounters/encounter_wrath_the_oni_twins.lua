-- THE ONI TWINS: the Twins lead the approach's elite. Fell the hornless sister and the horned one comes all the
-- way out; fell the horned one first and the hornless one has no mana to draw. Which sister first is the whole
-- fight.
-- Approved 2026-09-27 ("The Oni of Wrath", round 2).
local Band = require("models.band")

return {
    name = "The Oni Twins",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_oni_horned_twin", "character_oni_hornless_twin", "character_oni" }, ctx,
            "character_oni_student", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
