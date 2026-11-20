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
        -- Two on the approach, three on the seat (`per = 2`): at a flat two the seat's slimes rated
        -- 349 against floor one's 600-750 fights, and a company arriving on floor two walked them off.
        return Band.fill({}, ctx, "character_moss_slime", { base = 2, min = 2, per = 2, max = 4 })
    end,
}
