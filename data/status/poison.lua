-- Poison: a lingering toxin, the alchemist's answer to Burn (data/status/burn.lua). It works on the
-- CLOCK exactly as Burn does -- every elapsed tick costs the afflicted unit flat "poison" damage
-- (ctx.damage routes through Combat.dealFlatDamage, so a unit with poison `resist` shrugs some of it
-- off), and the same ticks count its duration down until it wears off. `magnitude` is quoted per turn
-- and ctx.accrue spreads it across the ticks. Inflicted by an Envenom charm
-- (data/items/utility/envenom.lua) infusing an adjacent weapon or item -- exactly as a Fire Stone
-- inflicts Burn.
--
-- Longer and gentler than Burn: it bites for less but lasts longer, so it rewards being applied
-- early and left to work rather than as a burst.
return {
    name = "Poison",
    abbr = "Psn",
    description = "Poisoned: takes toxic damage as time passes.",
    color = { 0.45, 0.72, 0.30 }, -- badge tint (venom green)
    duration = 5,
    magnitude = 3, -- poison damage per turn's worth of ticks (spread over the clock by ctx.accrue)
    debuff = true, -- removable by Cure / Panacea
    lingers = true, -- venom in the blood travels with its host, wherever it was picked up
    onTick = function(ctx)
        local n = ctx.accrue(ctx.magnitude)
        if n > 0 then ctx.damage(ctx.unit, n, { "poison" }) end
    end,
}
