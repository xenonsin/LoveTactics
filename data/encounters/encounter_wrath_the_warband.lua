-- THE WARBAND: the goblins' first lesson, on Wrath's approach (approved as pitched, 2026-09-26, "The Goblins of
-- Wrath"). Cutters and a Firebrand, and a Brute at the front of them. It teaches Blood Feud on its own: whoever
-- the company opens with is who they chase, and the Firebrand's trail punishes a chase across the board.
local Band = require("models.band")

return {
    name = "The Warband",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_goblin_brute", "character_goblin_firebrand" }, ctx,
            "character_goblin_cutter", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
