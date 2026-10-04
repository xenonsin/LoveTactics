-- MORA, THE TOLLKEEPER: Sloth's seat-floor elite ("Sloth's Bestiary", 2026-10-04, slice F). The toll-gate demon with
-- her collectors and a Bailiff (data/characters/character_mora.lua). Pay or fight: a company that spends whole turns
-- idle at her gate walks off the board and wins without her falling -- and without her drop.
--
-- Two collectors is the review's number and the band's centre; a heavier roll fields three.
local Band = require("models.band")

return {
    name = "Mora, the Tollkeeper",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "tundra" end,
    -- RUNG 2: the seat, floor 10 (an elite's rung is an exact lock: models/encounter.lua).
    rung = 2,
    objective = { type = "killAll" }, -- or paid through: Passage Paid wins it (models/toll.lua)
    composition = function(ctx)
        return Band.fill({ "character_mora", "character_bailiff" }, ctx, "character_toll_collector",
            { base = 2, min = 2, max = 3 })
    end,
}
