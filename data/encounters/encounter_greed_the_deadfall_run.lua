-- THE DEADFALL RUN: two Trapwrights and a Scale-Priest, with an egg behind the traps. Approved in round 1 as
-- the Tithe-Road (2026-09-24) and renamed in round 2 with the trap it is built round (2026-09-25). The
-- Trapwrights rig the ground as the company walks in, every planner walks round a rig, and the egg sits
-- where reaching it means crossing one -- or waiting out the turn the rocks take to fall.
--
-- HOMED ON THE SEAT (rung 2).
--
-- A BREAK, on the objective pass (2026-10-21): the egg behind the rig is the fight, and the Trapwrights are
-- what stands between. A Wyrmling is a mark beside the egg because a hatching takes the egg off the board --
-- an egg brooded through has to be killed as what it became, not counted as broken.
local Band = require("models.band")

return {
    name = "The Deadfall Run",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_kobold_trapwright", "character_kobold_trapwright",
                           "character_kobold_scale_priest", "character_dragon_egg" },
            ctx, "character_kobold_skulker", { base = 1, per = 6, max = 2 })
    end,
    objective = {
        type = "assassinate", verb = "Break", enemy = "the egg",
        targets = { "character_dragon_egg", "character_wyrmling" },
    },
}
