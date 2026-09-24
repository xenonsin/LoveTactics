-- THE MOSS SLIMES: the wood's slimes, on both of Gluttony's floors (no `rung`).
--
-- The soft first asking of the fen's question (data/encounters/encounter_fen_ooze.lua). Those void
-- steel; these only resist it (data/characters/character_moss_slime.lua), so this is ordinary traffic
-- a pair with no element can still win -- slowly -- and a company carrying fire wins quickly. They
-- eat each other (ability_coalesce), so a board left to stand beside itself gets fewer, fatter slimes.
local Band = require("models.band")

return {
    name = "The Moss Slimes",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_moss_slime", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
