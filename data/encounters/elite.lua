-- Encounter blueprint. A tougher fight that only appears once the player has
-- some renown, and grows more common at higher prestige (dynamic weight).
return {
    name = "Phoenix",
    kind = "elite",
    minPrestige = 2,
    weight = function(ctx) return (ctx.prestige or 1) end,
    -- A champion backed by an escort that grows with prestige.
    composition = function(ctx)
        local list = { "champion" }
        for i = 1, math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "bandit" end
        return list
    end,
}
