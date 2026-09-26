-- THE CENSER: fire and spore-smoke on Lust's approach, with nobody shoving.
--
-- The fire elementals burn only inside an elite on this floor (the Flue). This is the cheap version:
-- two flames and the mushroom folk's Puffers, so the board fills with ground a company has to walk around
-- rather than ground it is thrown onto. Neither body roots or shoves, so it belongs in either half.
--
-- Approved on review 2026-09-25 (variety round 1, `l3_censer`): floor three dealt six ordinary fights
-- where Gluttony's approach dealt nine.
local Band = require("models.band")

return {
    name = "The Censer",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_fire_elemental", "character_fire_elemental" }
        return Band.fill(list, ctx, "character_swooncap_puffer", { base = 1, per = 6, max = 2 })
    end,
}
