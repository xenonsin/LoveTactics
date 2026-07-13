-- Poison: a lingering toxin, the alchemist's answer to Burn (data/status/burn.lua). At the start of
-- each of the afflicted unit's turns it takes flat "poison" damage (ctx.damage routes through
-- Combat.dealFlatDamage, so a unit with poison `resist` shrugs some of it off), then the duration
-- counts down until it wears off. Inflicted by an Envenom charm (data/items/utility/envenom.lua)
-- infusing an adjacent weapon or item -- exactly as a Fire Stone inflicts Burn.
--
-- Longer and gentler than Burn: it ticks for less but lasts longer, so it rewards being applied
-- early and left to work rather than as a burst.
return {
    name = "Poison",
    abbr = "Psn",
    description = "Poisoned: takes toxic damage at the start of each turn.",
    color = { 0.45, 0.72, 0.30 }, -- badge tint (venom green)
    duration = 5,
    magnitude = 3, -- poison damage per turn
    debuff = true, -- removable by Cure / Panacea
    onTurnStart = function(ctx)
        ctx.damage(ctx.unit, ctx.magnitude, { "poison" })
    end,
}
