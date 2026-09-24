    -- THE CRYSTAL SLIMES: Pride's slimes on the spire's approach floor (rung 1). Only the lowest of them can
-- be hurt at a time, so the fight is fought in order.
    local Band = require("models.band")

    return {
        name = "The Crystal Slimes",
        kind = "elite",
        weight = 2,
        condition = function(ctx) return ctx.biome == "spire" end,
        rung = 1,
        composition = function(ctx)
            return Band.fill({}, ctx, "character_crystal_slime", { base = 3, min = 3, per = 5, max = 4 })
        end,
    }
