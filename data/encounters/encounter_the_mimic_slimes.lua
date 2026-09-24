    -- THE MIMIC SLIMES: Envy's slimes on the desert's approach floor (rung 1). Every one of them becomes
-- whoever looks at it first, and every blessing the company takes, they take too.
    local Band = require("models.band")

    return {
        name = "The Mimic Slimes",
        kind = "elite",
        weight = 2,
        condition = function(ctx) return ctx.biome == "desert" end,
        rung = 1,
        composition = function(ctx)
            return Band.fill({}, ctx, "character_mimic_slime", { base = 2, per = 4, max = 3 })
        end,
    }
