-- Encounter blueprint. Only roams the wilds (conditional example): excluded
-- from the castle biome. See data/encounters/boar.lua for the shape.
return {
    name = "Ancient Stag",
    kind = "combat",
    weight = 2,
    minPrestige = 1,
    condition = function(ctx) return ctx.biome ~= "castle" end,
}
