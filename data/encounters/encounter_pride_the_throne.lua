-- THE THRONE: the seat's elite, and a raid. The Throne never moves; it lights the floor in turn (the Decree),
-- chains two of the company together every third turn (the Sentence), and calls two Heralds at every quarter of its
-- health (Hosanna). An Ophan turns beside it and a Herald sings over both.
-- Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- RUNG 2, AND ON AN ELITE THAT IS AN EXACT LOCK: one elite, one floor (tests/elite_floor_spec.lua). Whether Pride's
-- seat BILLS it as the floor's named threat is Descent.SINS' `elites`, which the coordinator wires.
local Band = require("models.band")

return {
    name = "The Throne",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_throne", "character_ophan" }, ctx,
            "character_herald", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
