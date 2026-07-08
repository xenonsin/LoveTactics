-- Stun: shoves the target down the turn order by adding ticks to its initiative. The shove is
-- applied once, on cast (onApply); `duration` just keeps the "Stunned" badge visible for roughly
-- as long as the delay lasts. See models/status.lua for the hook contract.
return {
    name = "Stun",
    abbr = "St",
    description = "Shoved down the turn order, delaying the target's next turn.",
    color = { 0.95, 0.85, 0.35 }, -- badge tint (gold)
    magnitude = 5,                -- ticks added to the target's initiative
    duration = 5,                 -- ticks the badge lingers
    onApply = function(ctx)
        ctx.unit.initiative = ctx.unit.initiative + (ctx.magnitude or 0)
    end,
}
