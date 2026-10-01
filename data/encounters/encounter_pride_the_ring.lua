-- THE RING: a bladedancer that no blow which rolls can touch while it is Unblemished, and retainers to keep the
-- company busy while it dances. Bring something that does not ask the dice.
-- Approved 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "The Ring",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_elf_bladedancer" }, ctx, "character_elf_retainer", { base = 2, per = 6, max = 3 })
    end,
}
