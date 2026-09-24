    -- THE CALDERA KING on the pit's seat floor (rung 2), over two of his own. KILLALL: his pieces are
-- already Seething, and the fight is not over until they are down.
    local Band = require("models.band")

    return {
        name = "The Caldera King",
        kind = "elite",
        weight = 2,
        condition = function(ctx) return ctx.biome == "volcanic" end,
        rung = 2,
        composition = function(ctx)
            return Band.fill({ "character_caldera_king" }, ctx, "character_cinder_slime", { base = 2, min = 2, per = 7 })
        end,
    }
