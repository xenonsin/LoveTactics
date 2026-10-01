-- ELF PATROL: the elves' ordinary traffic on the spire's approach -- retainers on the spears, and a longbow behind
-- them that never needs to move to find its shot. Mark the line wide before anyone is struck down.
-- Approved 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "Elf Patrol",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_elf_longbow" }, ctx, "character_elf_retainer", { base = 2, per = 6, max = 3 })
    end,
}
