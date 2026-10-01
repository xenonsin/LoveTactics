-- THE ELF-LORD: the elves' elite on the spire's approach. A lord whose Renown grows with every body his court fells,
-- and lends itself to every elf beside him -- fielded with a longbow, a bladedancer and retainers. The first death on
-- either side decides which way the fight leans.
-- Approved 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "The Elf-Lord",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_elf_lord", "character_elf_longbow", "character_elf_bladedancer" }, ctx,
            "character_elf_retainer", { base = 2, min = 1, per = 6, max = 3 })
    end,
}
