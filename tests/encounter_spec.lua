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
        name = "prestige gates encounters below their minDay",
        fn = function()
            local p1 = Encounter.pool({ day = 1, biome = "forest" })
            assert(not has(p1, "encounter_elite"), "elite (minDay 2) should be gated at prestige 1")
            assert(has(p1, "encounter_boar"), "boar should be available at prestige 1")
        end,
    },
    {
        name = "dynamic weight scales with prestige, and then stops",
        fn = function()
            local function eliteAt(p)
                return has(Encounter.pool({ day = p, biome = "forest" }), "encounter_elite")
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
            local pool = Encounter.pool({ day = 20, biome = "forest" })
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
            local forest = Encounter.pool({ day = 3, biome = "forest" })
            local castle = Encounter.pool({ day = 3, biome = "castle" })
            assert(has(forest, "encounter_stag"), "stag should roam the forest")
            assert(not has(castle, "encounter_stag"), "stag should not appear in the castle")
        end,
    },

    {
        name = "opensBattle answers for the ends and the errands, not only the rolled fights",
        fn = function()
            -- THE MARKER'S PROMISE, in table form. ui/overworld_map.lua draws one shared combat border
            -- on everything this says yes to, so a kind that drifts out of it stops looking like a fight
            -- while still being one -- which is precisely the state the errands were in.
            for _, enc in ipairs({
                { kind = "combat" },
                { kind = "elite" },
                { kind = "objective" },                                 -- the floor's own end
                { kind = "objective", questId = "quest_bastion_slot_01" }, -- an errand: an end that is a job
                { kind = "pack", composition = { "character_wolf" } },  -- the pile with something on it
            }) do
                assert(Encounter.opensBattle(enc),
                    (enc.kind or "?") .. " opens the arena and must wear the combat border")
            end

            -- ...and the two exceptions kind alone cannot see. A `meet` end is walked onto, not fought
            -- (the arena debut), and a pack dropped before the guard rule existed is a pickup.
            assert(not Encounter.opensBattle({ kind = "objective", meet = true }),
                "a meet end is a walk-out; promising a fight there is a lie the player walks into")
            assert(not Encounter.opensBattle({ kind = "pack" }),
                "an unguarded pack is a pickup")

            -- Nothing else on the board, and this list is the whole of the rest of markerColor's kinds.
            -- Asserted as a set rather than a sample, because the failure being guarded is a kind
            -- quietly joining the fights, and a sample cannot see one it does not name.
            for _, kind in ipairs({ "town", "treasure", "event", "rest", "relic_cache", "shrine",
                                    "merchant", "crossroads", "ascent", "stair",
                                    "dark", "spinner", "translation" }) do
                assert(not Encounter.opensBattle({ kind = kind }),
                    kind .. " is not a fight and must not wear the combat border")
            end

            assert(not Encounter.opensBattle(nil), "an empty tile is not a fight")
        end,
    },

    {
        name = "nobody restates the fight test beside the one that draws the border",
        fn = function()
            -- A SOURCE SCAN, because the defect this guards is a SECOND COPY rather than a wrong answer.
            -- The border and the battle branch were one question asked in two places, and the way that
            -- goes wrong is not that either is mistaken today -- it is that a kind is added to one of
            -- them a year from now. states/game.lua held `kind == "combat" or kind == "elite" or kind ==
            -- "objective"` twice; both read through Encounter.opensBattle now, and this fails if a third
            -- copy is written.
            --
            -- Scoped to the two files that own the question. models/overworld.lua tests the same kinds
            -- all over the generator and is right to: seating, guarding and tiering a fight are
            -- placement questions, asked before an encounter is a stop the player can walk onto.
            --
            -- `objective` IS THE TERM SCANNED FOR, and that is what makes the scan mean something rather
            -- than merely fire. Testing combat-and-elite together is common and usually correct --
            -- ui/overworld_map.lua's pipSteps does it and deliberately leaves the ends out, because a
            -- muster cannot price an escort. What says "this line is asking whether the arena opens" is
            -- the ends being IN, which is the exact clause the errands were missing from the border.
            for _, path in ipairs({ "states/game.lua", "ui/overworld_map.lua" }) do
                local f = assert(io.open(path, "r"), "cannot read " .. path)
                local src = f:read("*a"); f:close()
                local n = 0
                for line in src:gmatch("[^\n]+") do
                    n = n + 1
                    -- The notes quote the old test on purpose -- that is how they explain themselves --
                    -- so a line that is entirely a comment is not code and does not count.
                    if not line:match("^%s*%-%-") then
                        assert(not (line:match('"combat"') and line:match('"elite"')
                            and line:match('"objective"')), string.format(
                            "%s:%d restates the fight test; ask Encounter.opensBattle so the border "
                            .. "cannot drift from the branch that runs the battle", path, n))
                    end
                end
            end
        end,
    },
}
