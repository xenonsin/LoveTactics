-- THE STRONGROOM: a Hearthguard walking beside the dwarves who go for the gold. Reviewed 2026-09-24.
-- It teaches the heaps and Gold Fever: the Delvers and the Hornblower run for the floor's coin, the
-- Hearthguard keeps pace with whichever of them is closest and takes the blow meant for him -- and a
-- company that loots a heap first pulls the whole room onto itself, open-guarded.
--
-- HOMED ON THE APPROACH (rung 1), a touch lighter than The Dig so the lesson usually comes second.
--
-- HEAPS, on the objective pass (2026-10-21): carry out three and the fight is won, and every one the company
-- takes pulls the room onto it. The cave lays two to four on its own and the dwarves pocket what they reach,
-- so the fight scatters three more of its own -- a race the company can lose, not one it cannot start.
local Band = require("models.band")

return {
    name = "The Strongroom",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    scatter = { { id = "hazard_coin_heap", count = 3 } },
    composition = function(ctx)
        return Band.fill({ "character_dwarf_hearthguard", "character_dwarf_hornblower" }, ctx,
            "character_dwarf_delver", { base = 1, per = 6, max = 2 })
    end,
    objective = { type = "heaps", count = 3, enemy = "the dwarves" },
}
