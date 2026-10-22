-- THE CINDER BOAR: Act 0's flight pairing, met again in the wood (2026-10-21).
--
-- The survivors' stops (encounter_survivors_defend.lua, encounter_survivors_extract.lua) field newts
-- with a boar behind them, and this is that cast on floor one proper, with nobody to protect. Both
-- bodies are the unpinned copies (character_cinder_boar.lua, character_ember_newt.lua).
--
-- WHAT IT ASKS is a split: one body worth chewing through and two that sting from range while you do
-- it. The boar's Brimstone also leaves the ground burning (ability_demon_brimstone.lua), so where the
-- company stands to fight it matters for the rest of the bout.
local Band = require("models.band")

return {
    name = "The Cinder Boar",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    -- ONE BOAR AND TWO OR THREE NEWTS. The boar is a line body (tier 2, eighty health) and stays one --
    -- two of them is a different fight, and a heavier one than floor one's ordinary traffic.
    composition = function(ctx)
        local list = { "character_cinder_boar" }
        return Band.fill(list, ctx, "character_ember_newt", { base = 2, min = 2, max = 3, per = 6 })
    end,
}
