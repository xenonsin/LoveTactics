-- Encounter blueprint. Only roams the wilds (conditional example): excluded
-- from the castle biome. See data/encounters/boar.lua for the shape.
return {
    name = "Ancient Stag",
    kind = "combat",
    weight = 2,
    minPrestige = 1,
    condition = function(ctx) return ctx.biome ~= "castle" end,
    -- A lone beast, joined by a second at high prestige.
    composition = function(ctx)
        local list = { "character_stag_beast" }
        if (ctx.prestige or 1) >= 4 then list[#list + 1] = "character_stag_beast" end
        return list
    end,
}
