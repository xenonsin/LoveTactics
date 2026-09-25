-- THE ASSAY OFFICE: the Goldsmith and her guard. Reviewed 2026-09-24. The seat's support fight: the
-- Goldsmith gilds her kin, hastes them out of her coffer and patches them up, two Hearthguards walk
-- beside whoever runs for the gold, and a Delver comes up out of the floor. Kill the Goldsmith and the
-- rest stop getting faster; leave her and every heap a dwarf pockets buys another haste.
--
-- HOMED ON THE SEAT (rung 2).
local Band = require("models.band")

return {
    name = "The Assay Office",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_dwarf_goldsmith", "character_dwarf_hearthguard" }, ctx,
            "character_dwarf_delver", { base = 1, per = 6, max = 2 })
    end,
}
