-- THE GREEN-EYED MONSTER: the monster with a Jackal Weigher or two at its side, approach traffic on the Ribstone
-- Waste ("Envy's Bestiary", round 2). The pairing is the review's own point: the monster punishes a company that
-- stands together and the Weighers punish one that does not keep its health level, so no single formation answers
-- both.
local Band = require("models.band")

return {
    name = "The Green-Eyed Monster",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_green_eyed_monster" }, ctx, "character_jackal_weigher", { base = 1, min = 1, max = 2 })
    end,
}
