-- STARLIGHT WATCH: a starcaller lighting the company up with Witchlight and casting at the light, and retainers
-- holding the way to it. Approved 2026-09-30 ("Pride's Bestiary") as On the Span; renamed 2026-10-01 when the
-- Starcaller came off Exposure (data/characters/character_elf_starcaller.lua). The file keeps its id.
local Band = require("models.band")

return {
    name = "Starlight Watch",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_elf_starcaller" }, ctx, "character_elf_retainer", { base = 2, per = 6, max = 3 })
    end,
}
