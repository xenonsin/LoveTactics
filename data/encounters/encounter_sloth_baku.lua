-- BAKU, THE DREAM-EATER: an elite of Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice E). Baku in a cloud of
-- Poppy-Moths: every sword that reaches a moth puts somebody to sleep, and every sleeper within 3 feeds it. Wake
-- your own sleepers to starve it, and kill the moths first.
--
-- A CLOUD OF FOUR, ROLLED TO FIVE: the review's fight is "a cloud of 4", and a moth comes in clouds of 4-6. The
-- band rates at four and rolls only upward, inside the elite tier's six.
local Band = require("models.band")

return {
    name = "Baku, the Dream-Eater",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "tundra" end,
    -- RUNG 2: the seat, floor 10 (an elite's rung is an exact lock: models/encounter.lua).
    rung = 2,
    -- BAKU IS THE FIGHT (the objective pass, 2026-10-21): it falls and the cloud disperses. The moths keep drifting
    -- in while it stands, so the cloud cannot be cleared and starving it means reaching it. This REVERSES the
    -- explicit `killAll` the line shipped with.
    objective = {
        type = "assassinate", target = "character_baku", enemy = "Baku",
        waves = { { every = 12, from = "surround", maxAlive = 5, unless = "character_baku",
                    composition = { "character_poppy_moth", "character_poppy_moth" } } },
    },
    composition = function(ctx)
        return Band.fill({ "character_baku" }, ctx, "character_poppy_moth", { base = 4, min = 4, max = 5 })
    end,
}
