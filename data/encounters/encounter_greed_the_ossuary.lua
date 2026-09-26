local Band = require("models.band")

-- THE OSSUARY: Vesh's dead, dwarf and kobold, where they were laid down. The hammer fight -- the lattice
-- slips an edge and a point -- and the dwarves come up out of the floor while the kobolds pack round
-- whoever answers them. Reviewed 2026-09-25 ("The Dead Hand"); the dead never share a fight with the
-- living, so no living dwarf or kobold stands here.
return {
    name = "The Ossuary",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_dwarf_skeleton", "character_dwarf_skeleton" }, ctx, "character_kobold_skeleton",
            { base = 3, min = 3, per = 6, max = 4 })
    end,
}
