-- THE BLOOD MASS: a Communicant, its Fledglings and a Blood-Ghoul, on Wrath's seat (Wrath's vampires, 2026-09-26).
-- The Communicant pays its own blood so the Fledglings never reach Bloodlust; kill it first and two newly turned
-- vampires go thirsty at once, the ghoul standing between them.
local Band = require("models.band")

return {
    name = "The Blood Mass",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_communicant", "character_blood_ghoul" }, ctx,
            "character_fledgling", { base = 2, min = 1, max = 2 })
    end,
}
