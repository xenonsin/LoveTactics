-- THE OLD SLOTH: the tundra approach's sleeping elite ("Sloth's Bestiary", slice A, 2026-10-04;
-- data/characters/character_old_sloth.lua). The Megatherium opens Dormant with a full bank of 5, and a Ground
-- Sloth or two graze around it. It must be killed: the fight is when, and from where, to wake it.
--
-- Tundra-locked; `rung = 1` is an exact lock for an elite (the approach, floor 9). Played out, never walked off.
local Band = require("models.band")

return {
    name = "The Old Sloth",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 1,
    objective = { type = "killAll" },
    composition = function(ctx)
        return Band.fill({ "character_old_sloth" }, ctx, "character_ground_sloth", { base = 1, min = 1, max = 2 })
    end,
}
