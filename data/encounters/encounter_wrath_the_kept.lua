-- THE KEPT: a Fledgling and the Blood-Ghouls it drinks from, on Wrath's approach (Wrath's vampires, 2026-09-26).
-- The thralls are its water: while one stands beside it, it Feeds at Thirst 2 and never reaches Bloodlust. Kill
-- the ghouls and it goes thirsty -- but a ghoul killed beside your own line opens every vein around it.
local Band = require("models.band")

return {
    name = "The Kept",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_fledgling" }, ctx,
            "character_blood_ghoul", { base = 2, min = 2, max = 3 })
    end,
}
