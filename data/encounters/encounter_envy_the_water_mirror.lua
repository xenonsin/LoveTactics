-- THE WATER MIRROR: the Faceless line's elite on Envy's seat, and the Frieren test (reviewed 2026-10-01..03, "Envy's
-- Bestiary"). The pool stands alone because it does not need to bring anybody: at the opening bell it makes an exact
-- copy of every body in the company, and those are the fight. Swap opponents, then break the pool. So the roster is
-- the company's rather than a band's, which is why it is pinned (tests/encounter_spec.lua) instead of rolled.
--
-- RUNG 2, the seat, beside the Second Self (round 2 kept both). Wiring it into Descent.SINS' named elites is the
-- coordinator's, after every slice merges.
return {
    name = "The Water Mirror",
    kind = "elite",
    -- `alone = true` (2026-10-03, on integration): its roster is the company's own copies, made at the bell, so the cast the floor rates is the pool alone -- and the floor's median filter
    -- (Descent.floorPool) dropped it from the pool entirely. The Labyrinth's and the Sphinx's reason.
    alone = true,
    weight = 2,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function()
        return { "character_the_water_mirror" }
    end,
}
