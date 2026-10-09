-- THE DUKE'S COURT: the Archon Duke, a Greater Archon and two or three Lesser Archons, an elite on the Crown's floor
-- ("The Crown's Bestiary", slice A, 2026-10-09). The lesson: deny the Ascension. Every wisp that falls within 3 of
-- the Duke is a wisp the Duke may take, and at the third it Ascends -- so fight the court away from it, and kill the
-- wisps before they get there.
--
-- `elite`, so Arena.ELITE_CAP (6) seats the whole court. NO `rung`: the underworld is one floor, and the ground is
-- its pin (encounter_the_skeleton_king.lua's header).
local Band = require("models.band")

return {
    name = "The Duke's Court",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return Band.fill({ "character_archon_duke", "character_greater_archon" }, ctx, "character_lesser_archon",
            { base = 2, min = 2, max = 3 })
    end,
}
