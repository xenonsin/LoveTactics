-- THE NIGHT FLIGHT: a Fledgling and its bats, on Wrath's approach (Wrath's vampires, 2026-09-26). Keno's round-1
-- note on the Familiar was "many bats ok", and the reading approved in round 2 is a fight wider than an ordinary
-- stop: up to five bats round one Fledgling. Every bat that bites a living body carries the drink to the
-- Fledgling (Blood Courier), and the Fledgling Wing-Swaps onto whichever bat reached the backline.
--
-- AN ELITE, NOT ORDINARY TRAFFIC (built 2026-09-26). It was approved as an ordinary fight with its own ceiling of
-- six, and it measured 27 unit-turns against the skirmish budget of 22 (tests/skirmish_spec.lua): six bodies, five
-- of them fast fliers, is a long fight by construction. The brief said to make it an elite rather than shrink it,
-- so the swarm is kept whole and the label moved -- the elite tier's own ceiling is the six it asked for. A spare
-- on Wrath's approach, the Redcaps' precedent.
local Band = require("models.band")

return {
    name = "The Night Flight",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_fledgling" }, ctx,
            "character_familiar", { base = 4, min = 3, per = 12, max = 5 })
    end,
}
