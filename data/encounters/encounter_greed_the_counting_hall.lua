-- THE COUNTING HALL: the Hoard-Thane, his Hearthguards and a Hornblower. Reviewed 2026-09-24 and billed as
-- Greed's seat elite (Descent.SINS). Greed bills the haul, and this is the fight where the circle's tax
-- is the puzzle: every dwarf that falls fattens the Thane, every turn he is left alone he hires another
-- Delver out of his coffer, and everything he spends is gold the company was going to be paid.
--
-- The lever that is not a trade is the floor: loot a heap and every dwarf on the board comes for the looter
-- with Gold Fever -- open-guarded, and pulled off the Thane.
local Band = require("models.band")

return {
    name = "The Counting Hall",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_the_hoard_thane", "character_dwarf_hearthguard", "character_dwarf_hornblower" },
            ctx, "character_dwarf_delver", { base = 1, per = 6, max = 2 })
    end,
}
