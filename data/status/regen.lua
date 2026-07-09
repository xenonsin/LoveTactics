-- Regeneration: a restorative buff. At the start of each of the afflicted unit's turns it recovers
-- flat health (ctx.heal routes through Combat.applyHeal, clamped to max), then the duration counts
-- down inside combat's rebase until it wears off. The friendly mirror of Burn -- granted by standing
-- in a Sanctuary hazard (data/hazards/hazard_heal.lua).
return {
    name = "Regeneration",
    abbr = "Rgn",
    description = "Blessed: recovers health at the start of each turn.",
    color = { 0.40, 0.85, 0.50 }, -- badge tint (restorative green)
    duration = 3,
    magnitude = 8, -- health restored per turn
    onTurnStart = function(ctx)
        ctx.heal(ctx.unit, ctx.magnitude)
    end,
}
