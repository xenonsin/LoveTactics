-- ASH: what the Thunderhead drops as it turns (models/storm.lua's Ashfall; "Fire, Lightning, and Dirty Thunder",
-- 2026-09-27). The Cinderfall Flows are the one board where two lines always see each other across the lava; the
-- storm takes that away a few tiles at a time.
--
-- Two things, and both are the point. It SEALS A LINE as darkness does (sightCost 2, Combat.SIGHT_BLOCK), so a
-- bow or a bolt cannot be drawn across it; and whoever stands in it is Blinded. Unsided: the storm's own bolts need
-- a clear line too, so where it lays its ash is where it has chosen not to shoot.
--
-- Not the Burning Halo, which is a ring its wearer carries and which burns: this burns nobody, stays where it
-- falls, and hides what is behind it. It clears in two turns.
return {
    name = "Ash",
    description = "Blocks line of sight across it. Inflicts Blind on whoever stands in it.",
    tags = { "dark" },
    fx = { color = { 0.30, 0.28, 0.27 }, density = 1.2 },
    duration = 10,           -- two turns at Status.TICKS_PER_TURN
    disposition = "hostile", -- it blinds anybody, so the enemy AI steps round it as it steps round fire
    sightCost = 2,           -- Combat.SIGHT_BLOCK: one tile of it seals a line outright
    dousedByTags = { "water" }, -- rain lays ash as it lays smoke
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_blind")
    end,
}
