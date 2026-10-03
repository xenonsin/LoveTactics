-- THE RED STONE: a Homunculus walking the waste with Penitents at its side ("Envy's Bestiary", 2026-10-03, slice
-- C). The made thing gets up again, and the blind things strike whoever finished last -- so the company that takes
-- the Homunculus down in one round has to decide who acts last in that round.
local Band = require("models.band")

return {
    name = "The Red Stone",
    kind = "combat",
    weight = 2,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_red_homunculus" }, ctx, "character_sewn_eyed_penitent",
            { base = 1, min = 1, per = 6, max = 2 })
    end,
}
