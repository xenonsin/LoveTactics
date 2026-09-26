-- THE FANATICS: two Fanatics loose among the warband, and a Wolf-Rider, on Wrath's seat (approved as pitched,
-- 2026-09-26, "The Goblins of Wrath"). The arrows are the fight: step out of the lanes, or leave the goblins in
-- them. A disaster the company can steer, which is the deeper floor's lesson.
local Band = require("models.band")

return {
    name = "The Fanatics",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_goblin_fanatic", "character_goblin_fanatic",
            "character_goblin_wolf_rider" }, ctx, "character_goblin_cutter", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
