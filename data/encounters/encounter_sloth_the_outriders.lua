-- THE OUTRIDERS: two Outriders and their collectors, on Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice F). The
-- riders charge through whoever stands in the open and come out the far side; the collectors hold the ground the
-- company would run to. Lesson: put your back to a wall -- a lane with nowhere to come out stops the ride dead.
--
-- Two riders always; one or two collectors, the review's band.
local Band = require("models.band")

return {
    name = "The Outriders",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_outrider", "character_outrider" }, ctx, "character_toll_collector",
            { base = 2, min = 1, max = 2 })
    end,
}
