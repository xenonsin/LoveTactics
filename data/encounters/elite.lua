-- Encounter blueprint. A tougher fight that only appears once the player has
-- some renown, and grows more common at higher prestige (dynamic weight).
return {
    name = "Phoenix",
    kind = "elite",
    minPrestige = 2,
    weight = function(ctx) return (ctx.prestige or 1) end,
}
