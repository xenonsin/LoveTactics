-- THE TOLLGATE: Toll-Collectors behind a Bailiff, on Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice F). The
-- Bailiff braces every Tollkeeper beside it, so the line is a gate; every one of them strikes a body that walks back
-- out of its reach. Lesson: commit where you engage -- and go around the gate, or break it with impact.
--
-- Three collectors is the review's number and the band's centre; a lighter roll fields two.
local Band = require("models.band")

return {
    name = "The Tollgate",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_bailiff" }, ctx, "character_toll_collector", { base = 3, min = 2, max = 3 })
    end,
}
