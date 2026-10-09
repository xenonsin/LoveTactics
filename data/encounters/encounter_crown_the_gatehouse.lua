-- THE GATEHOUSE: an Archon Warden, a Greater Archon and one or two Lesser Archons, ordinary traffic on the Crown's
-- floor ("The Crown's Bestiary", slice A, 2026-10-09). The lesson: close in, or shove the Warden off its post. From
-- range the court behind the Warden takes half; in melee it takes everything.
--
-- NO `rung`: the underworld is one floor, and the ground is its pin.
local Band = require("models.band")

return {
    name = "The Gatehouse",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return Band.fill({ "character_archon_warden", "character_greater_archon" }, ctx, "character_lesser_archon",
            { base = 1, min = 1, max = 2 })
    end,
}
