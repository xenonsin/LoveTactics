-- THE SPARRING GROUND (Wrath, floor 7): two Acolytes and an Adept. The Adept spends its chi on Flurry while the
-- Acolytes fill theirs, and a Burst beside it heats it too (Wrath spreads, models/asura.lua).
local Band = require("models.band")

return {
    name = "The Sparring Ground",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_asura_adept", "character_asura_acolyte" }, ctx,
            "character_asura_acolyte", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
