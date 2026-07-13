-- Burn: a lingering fire debuff. At the start of each of the afflicted unit's turns it takes flat
-- fire damage (ctx.damage routes through Combat.dealFlatDamage, so the "fire" tag is subject to any
-- fire resist), then the duration counts down inside combat's rebase until it wears off. Inflicted
-- deterministically by fire-augmented attacks -- e.g. a weapon sitting adjacent to a Fire Stone
-- (data/items/utility/fire_stone.lua).
return {
    name = "Burn",
    abbr = "Brn",
    description = "Scorched: takes fire damage at the start of each turn.",
    color = { 0.85, 0.45, 0.2 }, -- badge tint (ember orange)
    duration = 3,
    magnitude = 4, -- fire damage per turn
    debuff = true, -- removable by Cure
    onTurnStart = function(ctx)
        ctx.damage(ctx.unit, ctx.magnitude, { "fire" })
    end,
}
