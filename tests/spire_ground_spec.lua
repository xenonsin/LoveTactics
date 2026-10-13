-- Tests for the spire's signature ground, the OPEN SPAN (data/hazards/hazard_open_span.lua), and for the castle's
-- Threshold lasting the fight.
--
-- The spire shipped naming hazard_exposure, the Coveted Blood's cloud -- SIDED to the alchemist who carries it. A
-- patch the arena lays has no owner, so Hazard.allied read every body as an ally and the ground opened nobody, and it
-- ran out on the censer's twelve-tick clock besides. These cases build the fight the way the game does and use the
-- ground it laid, because a blueprint that loads and a board that seeds it were both true while it did nothing.

local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Status = require("models.status")
local Biome = require("models.biome")
local Fixture = require("tests.support.fixture")

local OPEN = "hazard_open_span"
local VULN = "status_vulnerable_pierce"

local function walker(x, y)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = 100, 100
    return spawn
end

local function sideOf(c, side)
    for _, u in ipairs(c.units) do if u.alive and u.side == side then return u end end
end

return {
    {
        name = "the spire seeds the Open Span, an unsided ground that does not expire",
        fn = function()
            assert(Biome.hazardFor("spire").id == OPEN, "the spire seeds " .. OPEN
                .. ", got " .. tostring(Biome.hazardFor("spire").id))
            local def = Hazard.defs[OPEN]
            assert(def, "the Open Span loads")
            assert((def.duration or 0) > 1000, "the span does not expire mid-fight")
            assert(Hazard.defs.hazard_exposure, "the Coveted Blood's cloud is left alone")
        end,
    },
    {
        name = "the Open Span opens a body of EITHER side to the point, and lets go when it steps off",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), walker(5, 5), { walker(7, 7) })
            for _, side in ipairs({ "party", "enemy" }) do
                local u = sideOf(c, side)
                assert(u, "a body on the " .. side .. " side")
                Hazard.place(c, u.x, u.y, OPEN)
                Hazard.onEnter(c, u, u.x, u.y)
                assert(Status.has(u, VULN), "the span opens the " .. side .. " body")
            end
            local u = sideOf(c, "party")
            u.x = 2
            Hazard.reap(c, u)
            assert(not Status.has(u, VULN), "stepping off the span lifts it")
        end,
    },
    {
        name = "the Open Span lands live on a real spire fight board, and stays the fight",
        fn = function()
            local EncounterBattle = require("models.encounter_battle")
            local found = 0
            for seed = 1, 4 do
                local built = EncounterBattle.build({ encounter = Encounter.get("encounter_pride_on_the_span"),
                    biome = "spire", depth = 13, seed = seed * 104729 })
                local c = built.combat
                local patch
                for _, h in ipairs(c.hazards or {}) do
                    if h.id == OPEN and h.alive then patch = h end
                end
                if patch then
                    found = found + 1
                    assert((patch.remaining or 0) > 1000, "the span does not run out mid-fight")
                    local foe = sideOf(c, "enemy")
                    foe.x, foe.y = patch.x, patch.y
                    Hazard.onEnter(c, foe, patch.x, patch.y)
                    assert(Status.has(foe, VULN), "the laid span opens a body the arena put no owner on")
                    Hazard.tick(c, 100)
                    assert(patch.alive, "a hundred ticks later the span is still there")
                end
            end
            assert(found >= 3, "the spire lays its span on its fight boards (" .. found .. " of 4)")
        end,
    },
    {
        name = "the castle's Threshold lasts the fight rather than twenty ticks",
        fn = function()
            assert(Biome.hazardFor("castle").id == "hazard_threshold", "the castle seeds the threshold")
            assert((Hazard.defs.hazard_threshold.duration or 0) > 1000, "a doorway does not expire mid-fight")
            local c = Fixture.combat(Fixture.new(12, 12), walker(5, 5), { walker(7, 7) })
            Hazard.place(c, 9, 9, "hazard_threshold")
            Hazard.tick(c, 100)
            assert(Hazard.at(c, 9, 9, "hazard_threshold"), "the threshold is still standing a hundred ticks on")
        end,
    },
}
