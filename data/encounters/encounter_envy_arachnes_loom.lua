-- ARACHNE'S LOOM: Arachne at her loom, with the glass that drifts across the waste ("Envy's Bestiary", 2026-10-03,
-- slice C). The motes strip what the company set up, and the company's answer is to cast it again -- which is the
-- thread she is waiting for. Vary the casts.
local Band = require("models.band")

return {
    name = "Arachne's Loom",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_arachne" }, ctx, "character_glass_mote",
            { base = 1, min = 1, per = 6, max = 2 })
    end,
}
