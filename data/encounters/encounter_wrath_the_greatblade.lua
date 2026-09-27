-- THE GREATBLADE: nothing the company brought to control her lands, and the Students make it choose where the
-- damage goes.
-- Approved 2026-09-27 ("The Oni of Wrath", round 2).
local Band = require("models.band")

return {
    name = "The Greatblade",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_oni_greatblade" }, ctx,
            "character_oni_student", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
