-- Encounter blueprint. Only roams the wilds (conditional example): excluded
-- from the castle biome. See data/encounters/boar.lua for the shape.
return {
    name = "Ancient Stag",
    kind = "combat",
    weight = 4, -- see encounter_boar.lua: the four road fights were doubled together
    minDay = 1,
    condition = function(ctx) return ctx.biome ~= "castle" end,
    -- A lone beast, joined by a second late in the campaign.
    composition = function(ctx)
        local list = { "character_stag_beast" }
        if (ctx.day or 1) >= 4 then list[#list + 1] = "character_stag_beast" end
        return list
    end,
}
