-- THE BLOOD COUNTESS: Wrath's seat elite (Wrath's vampires, rounds 2-3, approved 2026-09-27). The Countess, her
-- Blood Basin in the middle of the board, two Blood-Ghouls and her Familiars. Every point of Bleed damage anywhere
-- fills the basin; full, she bathes on her next turn (models/basin.lua). She shoves, the bats and ghouls keep the
-- wounds open, and the company chooses between breaking the basin and holding still.
--
-- ITS OWN CEILING OF SEVEN (agent invention, 2026-09-27): the basin is a body on the roll, so the elite tier's six
-- would cut the bats to one. `enemyCap = 7` seats two or three.
local Band = require("models.band")

return {
    name = "The Blood Countess",
    kind = "elite",
    weight = 1,
    enemyCap = 7,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_blood_countess", "character_blood_basin",
            "character_blood_ghoul", "character_blood_ghoul" },
            ctx, "character_familiar", { base = 2, min = 2, per = 8, max = 3 })
    end,
}
