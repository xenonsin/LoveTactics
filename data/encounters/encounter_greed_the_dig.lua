-- THE DIG: Delvers and a Hornblower, the dwarf line's first lesson. Reviewed 2026-09-24 ("The Dwarves of
-- Greed"). It teaches Delve -- a body that goes under and comes up a turn later beside you, harder each
-- time -- and Inheritance, on a light roster where killing the wrong one first is survivable.
--
-- HOMED ON THE APPROACH (rung 1). Deep-locked: Greed fights in the caves under the mountain (data/biomes/cave.lua).
local Band = require("models.band")

return {
    name = "The Dig",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_dwarf_hornblower" }, ctx, "character_dwarf_delver",
            { base = 2, min = 2, per = 6, max = 3 })
    end,
}
