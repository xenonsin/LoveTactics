-- THE TIDE: the Marid and a Djinni (reviewed 2026-09-30, "Pride's Bestiary"). The Marid floods and heals for
-- every Wet foe; the Djinni blows a company back out of the reach that would end it. Reach the Marid first, in a
-- corner it cannot blink out of, or stay out of the water.
--
-- HOMED ON THE APPROACH (rung 1).
local Band = require("models.band")

return {
    name = "The Tide",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_marid", "character_djinni" }, ctx,
            "character_gilded_page", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
