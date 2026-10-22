-- THE LEE OF THE RIDGE: Shades and a Glass-Eater, approach traffic on the Ribstone Waste ("Envy's Bestiary",
-- round 1). The Shades hide against the rock and Rattle what they touch; the eater walks out in the open and
-- strips. The fight is a question of where the company stands -- drive the Shades onto the sand.
--
-- THE OBJECTIVE (the objective pass, 2026-10-21): hold the middle ground. The Shades hide against the rock around
-- it, so holding it means driving them out onto the sand rather than chasing them into the lee.
local Band = require("models.band")

return {
    name = "The Lee of the Ridge",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_glass_eater" }, ctx, "character_shade", { base = 2, min = 2, max = 3 })
    end,
    objective = { type = "hold", region = "center", duration = 30, orKillAll = true, enemy = "the Shades" },
}
