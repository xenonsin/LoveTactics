-- THE PENITENTS: a file of Sewn-Eyed Penitents and the Echo that walks among them ("Envy's Bestiary", 2026-10-03,
-- slice C). The penitents strike whoever acted last; the Echo repeats whatever is cast beside her. So the order
-- the company takes its turns is the first decision, and where its casters stand is the second.
local Band = require("models.band")

return {
    name = "The Penitents",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_echo" }, ctx, "character_sewn_eyed_penitent",
            { base = 2, min = 2, per = 6, max = 3 })
    end,
}
