-- THE TANGLE: Giant Spiders, and nothing else. A spider fight is about GROUND, and each spider brings
-- three strands of its own (`seedsGround`) on top of the wood's two or three -- so at three spiders the
-- glade opens with a dozen strands in it, and choosing a lane is the fight. No other animal: a wolf
-- would path round the web the fight is built on, and a boar blundering into it is somebody else's fight.
--
-- GET THROUGH THE WEB (the objective pass, 2026-10-21): anyone on the far edge wins. The fight was always the
-- lane; now the lane is the win, and the spiders that keep dropping in are what make it a crossing.
--
-- Forest-locked with no depth gate, like the rest of the wood's stock (encounter_wolf_pack.lua argues
-- it): the circle owns a fixed stratum, and a depth on top would be a second opinion about where it goes.
local Band = require("models.band")

return {
    name = "The Tangle",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "forest" end,
    -- HOMED ON THE SEAT (rung 2): a circle gets harder going down (tests/combat_rung_spec.lua), and a
    -- glade strung before the bell is a harder stop than the wolves the approach is made of. It also
    -- thickens the seat, where the Herd was the only fight living; it strays onto the approach at
    -- Encounter.STRAY_SHARE, so the first floor still meets a spider now and then.
    rung = 2,
    composition = function(ctx)
        return Band.fill({}, ctx, "character_giant_spider", { base = 2, per = 6 })
    end,
    objective = {
        type = "reach", region = "far", place = "through the web", enemy = "the spiders",
        -- One spider at a time, every three turns, never past the opening count: the default trickle (half the
        -- line every 12 ticks) held one seed's company in the web for 125 turns.
        waves = { { every = 15, from = "back", composition = { "character_giant_spider" }, maxAlive = 3 } },
    },
}
