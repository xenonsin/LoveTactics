-- THE WARREN: Skulkers and a Trapwright round one egg, the kobold line's first lesson. Approved in both
-- review rounds (2026-09-24/25, "The Kobolds of Greed"). It teaches PACK -- three kobolds round one body is
-- the problem, and the answer is where the company stands -- and brooding: every kobold that ends its turn
-- beside the egg brings it nearer to hatching.
--
-- HOMED ON THE APPROACH (rung 1), beside the dwarves' Dig and Strongroom. Never shares a board with them:
-- the two races are rivals for the same caves, and a board has one enemy side.
local Band = require("models.band")

return {
    name = "The Warren",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_kobold_trapwright", "character_dragon_egg" }, ctx,
            "character_kobold_skulker", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
