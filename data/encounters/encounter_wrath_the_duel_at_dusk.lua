-- THE DUEL AT DUSK: a Vampire Duelist, a Blood-Ghoul and bats, on Wrath's approach (Wrath's vampires,
-- 2026-09-26). The Duelist's Mist Step eats the first blow each round and bleeds whoever threw it; the bats keep
-- the wounds open and carry the drink home. Spend a cheap blow on it before the real one.
local Band = require("models.band")

return {
    name = "The Duel at Dusk",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_vampire_duelist", "character_blood_ghoul" }, ctx,
            "character_familiar", { base = 2, min = 1, max = 2 })
    end,
}
