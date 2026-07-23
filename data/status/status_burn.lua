-- Burn: a lingering fire debuff. It sears on the CLOCK -- every tick that elapses costs the afflicted
-- unit fire damage (ctx.damage routes through Combat.dealFlatDamage, so the "fire" tag is subject to
-- any fire resist), and the same ticks count its duration down until it wears off. Inflicted
-- deterministically by fire-augmented attacks -- e.g. a weapon sitting adjacent to a Fire Stone
-- (data/items/utility/consumable_fire_stone.lua) -- or by standing in a Fire hazard (data/hazards/hazard_fire.lua).
--
-- `magnitude` is quoted PER TURN and ctx.accrue spreads it over the ticks a turn is worth
-- (Status.TICKS_PER_TURN), so the tuned number stays readable while the burning is continuous. Pricing
-- it on the clock is also the only way it is fair: a `duration` is measured in ticks, so a turn-driven
-- burn simply expired before a normal unit's next turn ever came around and cost it nothing at all.
-- Now a slow unit, whose turns are further apart, burns more between them -- as it should.
--
-- `lingers`, so a unit that walks out of the fire carries the flames with it and keeps burning for the
-- rest of the duration. The distinction that separates it from a zone-bound status like Regeneration,
-- which is over the moment you leave the hallowed ground (see models/hazard.lua).
return {
    name = "Burn",
    abbr = "Brn",
    description = "Scorched: takes fire damage as time passes.",
    color = { 0.85, 0.45, 0.2 }, -- badge tint (ember orange)
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN: the "few turns" the prose above promises
    magnitude = 4, -- fire damage per turn's worth of ticks
    debuff = true, -- removable by Cure
    lingers = true, -- fire caught in a zone comes with you when you leave it
    onTick = function(ctx)
        local n = ctx.accrue(ctx.magnitude)
        if n > 0 then ctx.damage(ctx.unit, n, { "fire" }) end
    end,
}
