-- RUDE AWAKENING: what a Dormant body wakes into (data/status/status_dormant.lua). "Sloth's Bestiary", 2026-10-04:
-- harmless until woken, and worse for it.
--
-- It lasts until the end of the woken body's NEXT turn (onTurnEnd). A Dormant body is woken by a blow, which lands
-- on somebody else's turn, so the next turn it ends is the first one it gets to swing in.
return {
    name = "Rude Awakening",
    abbr = "Rude",
    description = "Rudely awoken: increases damage by 4 and speed by 2 until the end of its next turn.",
    color = { 0.780, 0.420, 0.300 }, -- badge tint (raw red)
    duration = 99,
    hideDuration = true,
    statBonus = { damage = 4, speed = 2 },
    onTurnEnd = function(ctx) ctx.expire() end,
}
