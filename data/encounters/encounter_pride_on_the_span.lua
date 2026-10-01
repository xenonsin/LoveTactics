-- ON THE SPAN: a starcaller out on the Exposure that does nothing to it and pays it for standing there, and
-- retainers holding the way out to it.
-- Approved 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "On the Span",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_elf_starcaller" }, ctx, "character_elf_retainer", { base = 2, per = 6, max = 3 })
    end,
}
