-- THE BLOOD RING: the orcs' alpha fight, an elite on Wrath's approach (approved as pitched, 2026-09-26, "The Orcs of
-- Wrath"; Keno made the pit-fighter the alpha). The Grunts he brings are the crowd: his trait sits them on the
-- ring's edge, where they shove back anyone who ends a turn beside them, and sends one in each time a body falls.
-- On the approach because that floor was one elite short, where the Hobgoblin's Mob also stands.
--
-- KILL THE PIT-FIGHTER (the objective pass, 2026-10-21): the crowd is not the opponent. He falls and the ring
-- breaks up; the Grunts rout.
local Band = require("models.band")

return {
    name = "The Blood Ring",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_orc_pit_fighter" }, ctx,
            "character_orc_grunt", { base = 4, min = 4, per = 6, max = 6 })
    end,
    objective = { type = "assassinate", target = "character_orc_pit_fighter", enemy = "the Pit-Fighter" },
}
