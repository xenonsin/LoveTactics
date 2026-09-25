-- THE STRONGROOM: a Hearthguard walking beside the dwarves who go for the gold. Reviewed 2026-09-24.
-- It teaches the heaps and Gold Fever: the Delvers and the Hornblower run for the floor's coin, the
-- Hearthguard keeps pace with whichever of them is closest and takes the blow meant for him -- and a
-- company that loots a heap first pulls the whole room onto itself, open-guarded.
--
-- HOMED ON THE APPROACH (rung 1), a touch lighter than The Dig so the lesson usually comes second.
local Band = require("models.band")

return {
    name = "The Strongroom",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_dwarf_hearthguard", "character_dwarf_hornblower" }, ctx,
            "character_dwarf_delver", { base = 1, per = 6, max = 2 })
    end,
}
