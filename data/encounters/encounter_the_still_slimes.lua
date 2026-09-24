    -- THE STILL SLIMES: Sloth's three slimes together on the tundra's approach floor (rung 1) -- one
-- that takes your turns, one that taxes your effort, and one that grows while you deal with the others.
-- It is also the approach's first elite since the Winter Hart was cut.
    local Band = require("models.band")

    return {
        name = "The Still Slimes",
        kind = "elite",
        weight = 2,
        condition = function(ctx) return ctx.biome == "tundra" end,
        rung = 1,
        composition = function(ctx)
            return Band.fill({ "character_rime_slime", "character_frost_slime" }, ctx, "character_snowdrift_slime",
            { base = 1, min = 1, per = 5, max = 2 })
        end,
    }
