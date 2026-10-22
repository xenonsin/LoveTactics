-- THE FLIGHT: an Alpha Wyvern and the wyverns riding its wind -- the Wolf Pack's shape told in the air. The
-- same bodies as the Wyverns with a leader among them, and the leader makes the whole flight harder to hit
-- (Lead the Wind), so the fight has a kill order: Mark it, Root it, bring it down first.
--
-- Rung 2, forest-locked, a little rarer than the plain flight.
--
-- THE ALPHA IS THE WIN (the objective pass, 2026-10-21): bring it down and the flight scatters.
local Band = require("models.band")

return {
    name = "The Flight",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 2,
    composition = function(ctx)
        local list = { "character_wyvern_alpha" }
        return Band.fill(list, ctx, "character_wyvern", { base = 2, per = 8 })
    end,
    objective = { type = "assassinate", target = "character_wyvern_alpha", enemy = "the Alpha Wyvern" },
}
