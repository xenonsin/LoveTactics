-- THE RED MIST: a Hexer, a Sapper and Cutters, on Wrath's approach (approved as pitched, 2026-09-26, "The Goblins
-- of Wrath"). The mist lands where the two lines meet, and it teaches spacing on the floor that teaches the Feud:
-- nobody inside it wants a friend beside them, and the Sapper's kegs want a fire to set them off.
local Band = require("models.band")

return {
    name = "The Red Mist",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_goblin_hexer", "character_goblin_sapper" }, ctx,
            "character_goblin_cutter", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
