-- BEGRUDGED: the Pale Crone with an Evil Eye or two, approach traffic on the Ribstone Waste ("Envy's Bestiary",
-- round 4). Carry nothing to envy: the Eye sours the Fairest's blessings into Rattled and the Crone leaps on every
-- new one, so a company that buffs into this fight pays for it twice.
local Band = require("models.band")

return {
    name = "Begrudged",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_pale_crone" }, ctx, "character_evil_eye", { base = 1, min = 1, max = 2 })
    end,
}
