local Band = require("models.band")

-- THE CHARNEL: ghouls, and one barrow-wight to lay a body out for them. The blade fight, and the combo --
-- the wight puts somebody to sleep, the ghouls turn toward the sleeper, and a body that goes down is
-- robbed where it lies. Reviewed 2026-09-25 ("The Dead Hand").
return {
    name = "The Charnel",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_barrow_wight" }, ctx, "character_ghoul",
            { base = 3, min = 3, per = 8, max = 4 })
    end,
}
