-- BAD BLOOD: a goblin Fledgling inside a goblin warband, on Wrath's seat (Wrath's vampires, 2026-09-26). The
-- warband's Blood Feud and the Fledgling's Thirst, in one fight. Keep the Fledgling from drinking for two turns and
-- it is in Bloodlust, biting whatever is nearest -- and when that is a goblin, it becomes the warband's Feud and
-- they turn on it (models/feud.lua). The company's lever is the Fledgling's Thirst.
local Band = require("models.band")

return {
    name = "Bad Blood",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_goblin_fledgling", "character_goblin_brute" }, ctx,
            "character_goblin_cutter", { base = 2, min = 1, max = 2 })
    end,
}
