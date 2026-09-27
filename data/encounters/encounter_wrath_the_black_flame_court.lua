-- THE BLACK-FLAME COURT: the clan at full strength on the seat. The General domes the company, the Swordmaster
-- guards the dome's edge, and the Greatblade cannot be moved out of the way. Every clan death sends the rest Horn
-- Out.
-- Approved 2026-09-27 ("The Oni of Wrath", round 2).
local Band = require("models.band")

return {
    name = "The Black-Flame Court",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_oni_general", "character_oni_swordmaster", "character_oni_greatblade" }, ctx,
            "character_oni_student", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
