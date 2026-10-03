-- THE MASKED COMPANY: the Mask-Maker over a squad (reviewed 2026-10-01..03, "Envy's Bestiary"). Every Faceless
-- within 3 of it wears the face it is handed -- a shield, a healer, an archer and a caster -- and fights as a
-- company would. Kill the Mask-Maker and they go back to reading you one at a time; or kill the healer's face first.
--
-- Beside it a Doppelganger, which the Mask-Maker never masks (it is already somebody), and a Mirror-Knight when the
-- band rolls one, wearing whichever mask it is handed over its mirror. The line soldier (character_faceless) is
-- built on its own branch and is this squad's natural body once the branches meet.
--
-- WHY THE KNIGHT IS THE ROLLED BODY AND NOT A FIXED ONE: measured against the skirmish budget (22 unit-turns), the
-- Mask-Maker beside a fixed Mirror-Knight ran 26 -- the mirror turns a blow a round back onto the company, and a
-- shield's face under it stands a long time. Rolled, the fight is that one only sometimes.
--
-- HOMED ON THE SEAT (rung 2).
local Band = require("models.band")

return {
    name = "The Masked Company",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_mask_maker", "character_doppelganger" }, ctx,
            "character_mirror_knight", { base = 0, min = 0, per = 13, max = 1 })
    end,
}
