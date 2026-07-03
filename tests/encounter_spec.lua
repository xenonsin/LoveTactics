-- Tests for dynamic encounter selection (models/encounter.lua): prestige gating,
-- weight scaling, and conditional (biome) eligibility.

local Encounter = require("models.encounter")

local function has(pool, id)
    for _, e in ipairs(pool) do
        if e.id == id then return e end
    end
    return nil
end

return {
    {
        name = "encounter registry discovers def files by filename",
        fn = function()
            assert(Encounter.defs.boar, "boar missing")
            assert(Encounter.defs.elite, "elite missing")
        end,
    },
    {
        name = "prestige gates encounters below their minPrestige",
        fn = function()
            local p1 = Encounter.pool({ prestige = 1, biome = "forest" })
            assert(not has(p1, "elite"), "elite (minPrestige 2) should be gated at prestige 1")
            assert(has(p1, "boar"), "boar should be available at prestige 1")
        end,
    },
    {
        name = "dynamic weight scales with prestige",
        fn = function()
            local e2 = has(Encounter.pool({ prestige = 2, biome = "forest" }), "elite")
            local e4 = has(Encounter.pool({ prestige = 4, biome = "forest" }), "elite")
            assert(e2 and e2.weight == 2, "elite weight should equal prestige (2)")
            assert(e4 and e4.weight == 4, "elite weight should equal prestige (4)")
        end,
    },
    {
        name = "conditional encounter respects biome",
        fn = function()
            local forest = Encounter.pool({ prestige = 3, biome = "forest" })
            local castle = Encounter.pool({ prestige = 3, biome = "castle" })
            assert(has(forest, "stag"), "stag should roam the forest")
            assert(not has(castle, "stag"), "stag should not appear in the castle")
        end,
    },
}
