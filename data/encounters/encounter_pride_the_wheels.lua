-- THE WHEELS: two Ophanim and a Herald. Every tile beside a wheel is struck every turn, and nothing steps aside
-- from it -- so the fight is decided by who stands where, and by reach. Reviewed 2026-09-30 ("Pride's Bestiary").
local Band = require("models.band")

return {
    name = "The Wheels",
    kind = "combat",
    weight = 2,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2, -- the seat
    composition = function(ctx)
        return Band.fill({ "character_ophan", "character_ophan", "character_herald" }, ctx,
            "character_herald", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
