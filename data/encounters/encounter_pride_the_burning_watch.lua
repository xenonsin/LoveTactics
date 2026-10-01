-- THE BURNING WATCH: two Seraphs and the Heralds that bless them. Whoever starts a turn beside a Seraph burns, so
-- the fight is struck and left, never stood in. Reviewed 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "The Burning Watch",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2, -- the seat
    composition = function(ctx)
        return Band.fill({ "character_seraph", "character_seraph" }, ctx,
            "character_herald", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
