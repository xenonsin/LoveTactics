-- Encounter blueprint. See data/encounters/boar.lua for the shape.
return {
    name = "Dire Wolf",
    kind = "combat",
    weight = 6, -- see encounter_boar.lua: the four road fights were doubled together
    minDay = 1,
    -- A pack that grows as the campaign runs on, and gains an alpha late.
    composition = function(ctx)
        local p = ctx.day or 1
        local list = {}
        for i = 1, 2 + math.floor(p / 2) do list[i] = "character_wolf_grunt" end
        if p >= 3 then list[#list + 1] = "character_wolf_alpha" end
        return list
    end,
}
