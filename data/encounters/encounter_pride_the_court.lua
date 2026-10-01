-- THE COURT: a highborn whose Unblemished comes back after any round it goes untouched, and longbows that make
-- every round the company spends on it a round it is shot. Keep it marked, or watch the badge return.
-- Approved 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "The Court",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_elf_highborn" }, ctx, "character_elf_longbow", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
