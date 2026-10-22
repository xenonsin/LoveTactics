-- THE GOBLIN KING'S COURT: the King on his throne in the Rigged Hall, an elite on Wrath's seat (round 1 and 2,
-- 2026-09-26, "The Goblins of Wrath"). He pulls a lever a turn, the marked row opens into fire and downs whoever
-- is on it -- his court too -- and he throws his goblins at the company and lets a Fanatic out of its cage. The
-- court comes in waves, which keeps the rows full of bodies worth dropping.
--
-- KILL THE KING (the objective pass, 2026-10-21): the court keeps coming while he sits, so the fight is the
-- throne and not the floor. The waves stay; they are what makes the walk to him cost.
local Band = require("models.band")
local Status = require("models.status")

local TURN = Status.TICKS_PER_TURN

return {
    name = "The Goblin King's Court",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_goblin_king", "character_goblin_brute" }, ctx,
            "character_goblin_cutter", { base = 2, min = 2, per = 6, max = 3 })
    end,
    objective = {
        type = "assassinate", target = "character_goblin_king", enemy = "the Goblin King",
        waves = {
            { at = 2 * TURN, every = 3 * TURN, count = 3, from = "surround", maxAlive = 8,
              unless = "character_goblin_king",
              composition = function() return { "character_goblin_cutter", "character_goblin_cutter" } end },
        },
    },
}
