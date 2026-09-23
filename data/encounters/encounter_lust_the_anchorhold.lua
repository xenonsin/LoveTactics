-- THE ANCHORHOLD: the Alraune Anchoress in her cell, and the Hold half of the circle's elite.
--
-- She is walled in -- she cannot be moved and she does not walk -- so the company goes to her, through a
-- garden of Mandrakes that root it on her honey and scream when they die. Her Compline rings all of them
-- at once, a turn after she starts it; every death near her plants another. The fight is where your
-- company falls, because every place it falls becomes a thing that roots and screams.
--
-- BILLED NOWHERE, on the Lady Chapel's argument (Descent.SINS' Lust entry): both rungs are already billed
-- to the circle's two first animals, and a spare turns up at ELITE_WEIGHT. RUNG 1 -- the approach, beside
-- the Flue: it is the Hold half's lesson, and the Churchyard Yew is the Move half's on the seat. One
-- elite, one floor: see models/encounter.lua's eligibility note.
--
-- HOLD ONLY (tests/greed_lust_circle_spec.lua sweeps every Lust roster for the mix).
local Band = require("models.band")

return {
    name = "The Anchorhold",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "castle" end,
    rung = 1,
    composition = function(ctx)
        local list = { "character_alraune_anchoress", "character_mandrake", "character_mandrake" }
        return Band.fill(list, ctx, "character_swooncap_puffer", { base = 1, per = 6, max = 2 })
    end,
}
