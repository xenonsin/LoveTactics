-- THE WISHMAKER: Pride's seat elite (reviewed 2026-09-30, "Pride's Bestiary"). An elf archmage and her Lamp.
--
-- The Lamp grants a wish at each third of her health -- whole again, the company's best boon, and at the last a
-- Great Djinn that cannot fall while the Lamp stands. Breaking the Lamp is the whole fight; WHEN is the decision.
--
-- RUNG 2 -- the seat, which stood no elite of its own since the Gallery moved to the approach. Which floor BILLS
-- it (Descent.SINS' `elites`) is the coordinator's to wire, not this file's.
local Band = require("models.band")

return {
    name = "The Wishmaker",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_wishmaker", "character_the_lamp" }, ctx,
            "character_gilded_page", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
