-- Blighted: standing on ground that has gone wrong, and being hurt by it for exactly as long as you
-- stand there.
--
-- THE ZONE-BOUND MIRROR OF POISON, and the split is the whole reason this file exists rather than
-- reusing the venom the game already has. `status_poison` declares `lingers = true` -- "venom in the
-- blood travels with its host, wherever it was picked up" -- which is the correct reading of a toxin
-- and the wrong one for a floor. What the Vengeful Spirit's ground does is not something it puts INTO
-- you; it is something that is true of the tile. Step off and it stops, because you are no longer
-- standing on it.
--
-- So this takes Regeneration's rule rather than Burn's: no `lingers`, which is all it takes
-- (models/hazard.lua's reap owns the rest). Regeneration's own header names itself "the archetype of a
-- ZONE-BOUND status"; this is that archetype pointed the other way, and the pair are deliberately
-- symmetrical because in this fight they are literally the same tiles before and after
-- (data/hazards/hazard_blight.lua).
--
-- WHAT IT COSTS THE PLAYER IS THE BOARD, NOT THE PARTY, and that follows from the rule above rather
-- than from a number. A threshold that dealt a lump of damage to everyone standing in the wrong place
-- would be a bill for a habit the fight spent its whole first half teaching, arriving with no warning
-- (the wilt tell was cut). Ground that hurts only while you are on it is a bill you can refuse by
-- moving -- so the reversal can afford to be a surprise, which is the only reason the two decisions
-- work together.
--
-- `duration` is a backstop in the same sense Regeneration's is: inside a zone it is refreshed every
-- tick the unit remains and never gets a chance to matter. It is reachable only if something grants
-- this away from ground, which nothing currently does.
return {
    name = "Blighted",
    abbr = "Blt",
    description = "Blighted: the ground itself is taking from you.",
    color = { 0.541, 0.380, 0.596 }, -- badge tint (sour violet: not poison's green, not burn's orange)
    fx = { field = true }, -- draws ground under the body (a debuff: the hostile look, ui/field_fx.lua)
    duration = 15, -- ~3 turns; only ever reached off a zone -- see above
    magnitude = 5, -- damage per turn's worth of ticks, spread over the clock by ctx.accrue
    debuff = true, -- removable by Cure / Panacea -- though stepping off is free and faster
    onTick = function(ctx)
        local n = ctx.accrue(ctx.magnitude)
        -- Tagged `poison` rather than untyped: a body that resists venom resists a rotting floor, which
        -- is the reading every existing coat and innate line in the game already agrees with, and it
        -- keeps the Vengeful Spirit's own immunity to its ground a single ordinary resist entry.
        if n > 0 then ctx.damage(ctx.unit, n, { "poison" }) end
    end,
}
