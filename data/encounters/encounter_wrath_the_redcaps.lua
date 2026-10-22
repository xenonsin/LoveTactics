-- THE REDCAPS: a Redcap and Cutters, on Wrath's seat (approved as pitched, 2026-09-26, "The Goblins
-- of Wrath"; the Redcap re-made an assassin in round 2). The Cutters wound, and the Redcap blinks to
-- whatever they leave below half. The deeper floor asks the company to keep its health up, not to be clever.
--
-- AN ELITE, NOT ORDINARY TRAFFIC (built 2026-09-26). It was approved as an ordinary fight, and it measured 36
-- unit-turns against the skirmish budget of 22 (tests/skirmish_spec.lua). The cause is the table the review
-- asked for: an assassin grows two Speed a level, so at Wrath's depth the Redcap simply takes more turns than
-- anything else on the board -- the same body on the fighter table ran in 7. The class was the author's call
-- and stays; the label moves instead (a body that makes a fight long by construction is an elite, a MARKED
-- stop the company reads and routes around). A spare on Wrath's seat.
--
-- KEEP THE DELVER ALIVE (the objective pass, 2026-10-21): a Stray Delver opens wounded, just above half. One cut
-- puts it under, and under half is what the Redcap blinks to. The company is asked to keep somebody else's health
-- up, not only its own. (Opened below half, the Redcap took it before the company had moved: 1 unit-turn, lost.)
local Band = require("models.band")

return {
    name = "The Redcaps",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_redcap" }, ctx,
            "character_goblin_cutter", { base = 1, min = 1, per = 6, max = 2 })
    end,
    allies = { "character_stray_delver" },
    objective = {
        type = "killAll", enemy = "the Redcaps",
        protect = "character_stray_delver", anchor = "rally",
        chargeOpens = { health = 0.6 },
    },
}
