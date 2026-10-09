-- CERBERUS: the dog at the gate, and a hound or two of its kennel ("The Crown's Bestiary", slice C, approved
-- 2026-10-09). The lesson is who stands beside it: every body adjacent is a bite, so one body beside it is one bite,
-- and the rest of the company fights from range, puts heads to sleep, and chooses which third to break first.
--
-- `elite`, so Arena.ELITE_CAP gives it room, and KILLALL: the hounds' fire is half of why standing back is hard.
-- No `rung`: the underworld is the single floor under the circles, and the ground is the pin.
local Band = require("models.band")

return {
    name = "Cerberus",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        local list = { "character_cerberus" }
        return Band.fill(list, ctx, "character_hellhound", { base = 1, max = 2 })
    end,
}
