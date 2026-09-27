-- THE MASQUE: a Vampire Duelist and a Hemomancer with bats, on Wrath's seat (Wrath's vampires, 2026-09-26). The
-- Hemomancer opens veins across the company's line and boils the worst of them; the Duelist mists away from
-- the first blow and bleeds the striker; the bats keep everything running.
local Band = require("models.band")

return {
    name = "The Masque",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_vampire_duelist", "character_hemomancer" }, ctx,
            "character_familiar", { base = 2, min = 1, max = 2 })
    end,
}
