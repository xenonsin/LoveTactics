-- Encounter blueprint. See data/encounters/boar.lua for the shape.
return {
    name = "Dire Wolf",
    kind = "combat",
    weight = 3,
    minPrestige = 1,
    -- A pack that grows with prestige and gains an alpha at higher renown.
    composition = function(ctx)
        local p = ctx.prestige or 1
        local list = {}
        for i = 1, 2 + math.floor(p / 2) do list[i] = "wolf_grunt" end
        if p >= 3 then list[#list + 1] = "wolf_alpha" end
        return list
    end,
}
