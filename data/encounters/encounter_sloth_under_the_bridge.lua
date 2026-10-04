-- UNDER THE BRIDGE: a Toll-Troll by a meltwater lead, with a Troll or two. Approach traffic on the Meltwater Reach
-- (approved 2026-10-04, "Sloth's Bestiary", slice B). The lesson: bring fire, and act from outside the toll -- the
-- line trolls come at you regrowing, and the one that holds the bridge strikes whatever acts within two of it.
local Band = require("models.band")

return {
    name = "Under the Bridge",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_toll_troll" }, ctx, "character_troll", { base = 1, min = 1, max = 2 })
    end,
}
