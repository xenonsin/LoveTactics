-- THE DREAD OF THE WHITEOUT: the yeti matriarch and her yeti, the tundra approach's hunting elite ("Sloth's
-- Bestiary", slice A, 2026-10-04; data/characters/character_dread_of_the_whiteout.lua). The yeti root whoever stands
-- alone, and she drags the rooted off into the white.
--
-- TWO YETI, OR THREE. The fight row approved "the matriarch with 2 Yeti" and her body row "two or three yeti"; the
-- band's centre is the fight row's 2, and the seed may roll the third.
--
-- Tundra-locked; `rung = 1` is an exact lock for an elite (the approach, floor 9). Played out, never walked off.
local Band = require("models.band")

return {
    name = "The Dread of the Whiteout",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    objective = { type = "killAll" },
    composition = function(ctx)
        return Band.fill({ "character_dread_of_the_whiteout" }, ctx, "character_yeti", { base = 2, min = 2, max = 3 })
    end,
}
