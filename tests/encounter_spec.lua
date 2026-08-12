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
            assert(Encounter.defs.encounter_boar, "boar missing")
            assert(Encounter.defs.encounter_elite, "elite missing")
        end,
    },
    {
        name = "prestige gates encounters below their minPrestige",
        fn = function()
            local p1 = Encounter.pool({ prestige = 1, biome = "forest" })
            assert(not has(p1, "encounter_elite"), "elite (minPrestige 2) should be gated at prestige 1")
            assert(has(p1, "encounter_boar"), "boar should be available at prestige 1")
        end,
    },
    {
        name = "dynamic weight scales with prestige, and then stops",
        fn = function()
            local function eliteAt(p)
                return has(Encounter.pool({ prestige = p, biome = "forest" }), "encounter_elite")
            end
            local e2, e3 = eliteAt(2), eliteAt(3)
            assert(e2 and e2.weight == 2, "elite weight should track prestige while it climbs (2)")
            assert(e3 and e3.weight == 3, "elite weight should track prestige while it climbs (3)")

            -- THE CEILING IS THE POINT, and it is what this case is really for. The weight was
            -- `ctx.prestige` unbounded, against the fixed 4-6 an ordinary road fight carries, so past
            -- prestige ~6 the elite stopped being the tough fight and became the only fight -- measured
            -- at 76% of every board's combats (`. board-report`). An elite that is the ordinary case
            -- has nothing to be an elite against, and it flattens the board's whole difficulty arc,
            -- since Overworld:assignEncounterTiers reads rank as a step above depth.
            local e20, e50 = eliteAt(20), eliteAt(50)
            assert(e20 and e20.weight == 3, "elite weight must saturate, not climb with the campaign")
            assert(e50 and e50.weight == e20.weight, "and stay saturated however long the campaign runs")

            -- The saturated elite must stay a MINORITY of the pool's fight weight, which is the
            -- property the tier arc actually depends on. Asserted against the ordinary fights rather
            -- than against a literal, so retuning either side keeps this honest.
            local pool = Encounter.pool({ prestige = 20, biome = "forest" })
            local ordinary, elite = 0, 0
            for _, e in ipairs(pool) do
                if e.kind == "combat" then ordinary = ordinary + e.weight
                elseif e.kind == "elite" then elite = elite + e.weight end
            end
            assert(elite < ordinary / 2,
                string.format("elites must stay the exception on the road (elite %d vs combat %d)",
                    elite, ordinary))
        end,
    },
    {
        name = "conditional encounter respects biome",
        fn = function()
            local forest = Encounter.pool({ prestige = 3, biome = "forest" })
            local castle = Encounter.pool({ prestige = 3, biome = "castle" })
            assert(has(forest, "encounter_stag"), "stag should roam the forest")
            assert(not has(castle, "encounter_stag"), "stag should not appear in the castle")
        end,
    },
}
