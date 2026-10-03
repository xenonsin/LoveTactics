-- MEDUSA'S GARDEN: Envy's approach-floor elite (reviewed 2026-10-01..03, "Envy's Bestiary", row md_body). The
-- Gorgon and the three statues of past challengers she keeps; they stand Petrified until her half health and
-- then crack open and fight (models/gorgon.lua).
--
-- PINNED, NOT ROLLED (tests/encounter_spec.lua): "three statues stand on the board" is the review's number, and
-- the garden is the fight's second half -- a roll that fielded two would be a smaller second half nobody chose.
-- The adders arrive mid-fight off her blood, so the board grows anyway.
return {
    name = "Medusa's Garden",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "desert" end,
    -- RUNG 1: the approach, floor 11 (an elite's rung is an exact lock: models/encounter.lua).
    rung = 1,
    objective = { type = "killAll" }, -- played out, never walked off
    composition = function()
        return { "character_medusa", "character_stone_challenger", "character_stone_challenger",
                 "character_stone_challenger" }
    end,
}
