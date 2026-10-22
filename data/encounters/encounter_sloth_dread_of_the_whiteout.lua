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
    -- A STRAY DELVER WALKS WITH YOU (the objective pass, 2026-10-21), and the Dread hunts the lone one: keep the
    -- stranger alive through the clear. This REVERSES the explicit `killAll` the line shipped with; the clear is
    -- still the win, and the charge is what a company standing apart now costs.
    allies = { "character_stray_delver" },
    objective = { type = "killAll", enemy = "the yeti", protect = "character_stray_delver" },
    composition = function(ctx)
        return Band.fill({ "character_dread_of_the_whiteout" }, ctx, "character_yeti", { base = 2, min = 2, max = 3 })
    end,
}
