-- THE EVIL EYE: an Evil Eye over a nest of Sand-Eels, approach traffic on the Ribstone Waste ("Envy's Bestiary",
-- rounds 1 and 3). Both read the Fairest, so the fight is about one body: the eye sours its blessings and the eels
-- come up under it. Strip your own Fairest, or keep it behind a ridge and moving.
local Band = require("models.band")

return {
    name = "The Evil Eye",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_evil_eye" }, ctx, "character_sand_eel", { base = 2, min = 2, max = 3 })
    end,
}
