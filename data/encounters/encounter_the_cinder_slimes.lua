    -- THE CINDER SLIMES: Wrath's slimes on the pit's approach floor (rung 1). An elite, for the fen ooze's
-- reason: a body steel cannot touch is a thing a company sees and decides about.
    local Band = require("models.band")

    return {
        name = "The Cinder Slimes",
        kind = "elite",
        weight = 2,
        condition = function(ctx) return ctx.biome == "volcanic" end,
        rung = 1,
        composition = function(ctx)
            return Band.fill({}, ctx, "character_cinder_slime", { base = 2, per = 4, max = 3 })
        end,
    }
