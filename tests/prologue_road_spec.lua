-- Tests for HOW ACT 0 ENDS: the Champion stands on the way out, and killing it opens a road rather
-- than cutting to the city.
--
-- THE SHAPE IS THE DESCENT'S, borrowed on purpose. A circle's guardian stands on its stair and dying
-- OPENS it (models/descent.lua's Descent.openStair) instead of descending on the killing blow, because
-- winning must not take the rest of the board out of the player's hands. Act 0 ends the same way, for
-- a reason of its own: the kill is where the company reaches level 2 (prologue.EXIT_LEVEL), and a leg
-- that cut to the city on that frame had nowhere to put the level-up, the newly-opened class screen,
-- or the coach line pointing at it. Back on the map there is a board to stand on and time to read.
--
-- What is pinned here is the CONTRACT between the three pieces -- the objective's declaration, the
-- gate it opens, and the stop it leaves behind -- rather than any one of their implementations.

local prologue = require("states.prologue")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Player = require("models.player")

-- The Champion's objective, off the exported quest rather than by reaching into the state's locals --
-- the same reason prologue.FLIGHT_QUEST is exported at all (tests/flight_leg_spec.lua). It hangs off
-- the quest's `map`, which is the table states/game.lua reads the leg out of.
local function championObjective()
    return (prologue.FLIGHT_QUEST.map or {}).objective
end

return {
    {
        name = "the Champion stands on the way out rather than ending the leg",
        fn = function()
            local obj = championObjective()
            assert(obj, "the flight quest should carry an objective")
            assert(obj.win and obj.win.target == "character_demon_champion_tutorial",
                "the objective under test should be the Champion's")
            assert(obj.opensExit, string.format(
                "the Champion's objective must declare `opensExit` -- without it states/game.lua "
                .. "calls the prologue's onComplete on the killing blow and Act 0 cuts straight to "
                .. "the city, which is the beat this whole arrangement exists to stop"))
            assert(obj.opensExit.kind == "road",
                "the way out is a road stop, got " .. tostring(obj.opensExit.kind))
            assert(type(obj.opensExit.name) == "string" and #obj.opensExit.name > 0,
                "the road has to name itself -- it is a marker the player walks back to")
        end,
    },

    {
        name = "the road is a stop the board knows how to describe",
        fn = function()
            -- A kind that reaches a board without a sentence is a marker the player can only read by
            -- walking onto it, which is the failure Encounter.GLOSS exists to prevent. Asked through
            -- the same lookup the map's hover readout and the step's modal both use.
            local said = Encounter.gloss({ kind = "road" })
            assert(said and #said > 0, "the road stop has no gloss, so neither surface can say what it is")

            local listed = false
            for _, kind in ipairs(Encounter.MARKER_KINDS) do
                if kind == "road" then listed = true end
            end
            assert(listed, "`road` is missing from Encounter.MARKER_KINDS, so the gloss sweep skips it")
        end,
    },

    {
        name = "the class screen opens at the Champion, not only at the city",
        fn = function()
            -- THE GATE THIS BEAT MOVES. models/descent.lua argues at length that the Roll waits for
            -- the town -- "a body on the flight leg has one job, one kit and no ladder to read" --
            -- and that argument is dated rather than wrong: Act 0 pays a level now, so by the time
            -- the Champion falls there IS a ladder. The tab has to be open for the coach line
            -- pointing at it to mean anything.
            local p = Player.new()
            p.cityReached, p.classesOpen = nil, nil
            assert(not Descent.classesUnlocked(p),
                "the Roll must still be shut during the sweep, before the Champion")

            Descent.markClassesOpen(p)
            assert(Descent.classesUnlocked(p),
                "the Champion's fall must open the Roll -- the coach points at a tab that is not there")

            -- ...and the city's own mark still works on its own, for a company that skipped Act 0.
            local skipped = Player.new()
            skipped.cityReached, skipped.classesOpen = nil, nil
            Descent.markCityReached(skipped)
            assert(Descent.classesUnlocked(skipped),
                "reaching the city must still open the Roll by itself")
        end,
    },

    {
        name = "the Champion pushes the Armory's own class window, and spends its pip",
        fn = function()
            local Locale = require("models.locale")
            -- THE SAME WINDOW THE TAB WOULD HAVE OPENED, not a second one. ui/panels/party.lua opens
            -- `classes_title`/`classes_body` the first time the Roll is pressed; states/game.lua's
            -- teachClasses pushes that same pair when the Champion falls, because nobody has reached
            -- for the tab yet -- it did not exist a moment earlier.
            for _, id in ipairs({ "classes_title", "classes_body" }) do
                local text = Locale.line("conversation_tutorial_notes", id)
                assert(type(text) == "string" and #text > 0,
                    id .. " resolves to nothing -- the pushed window would open blank")
            end

            -- TWO LEDGERS, AND THEY ARE NOT THE SAME QUESTION. `classesOpen` is "the tab exists";
            -- `classesTaught` is "the lesson behind it has been read". Conflating them would either
            -- open the tab already silent, or re-teach it every time the Roll is pressed.
            local p = Player.new()
            p.cityReached, p.classesOpen, p.classesTaught = nil, nil, nil
            Descent.markClassesOpen(p)
            assert(Descent.classesUnlocked(p), "the Champion opens the tab")
            assert(not Descent.classesTaught(p),
                "opening the tab must not silently count as having read its lesson")

            Descent.markClassesTaught(p)
            assert(Descent.classesTaught(p),
                "reading the window at the Champion must spend the tab's pip, or the Roll teaches it twice")
        end,
    },

    {
        name = "and the mark survives a save written on the walk to the road",
        fn = function()
            -- The leg now LEAVES the player standing on a board with the tab freshly open, which is
            -- exactly where a save gets written (closing the Loadout panel writes one). A flag that
            -- did not round-trip would take the tab away again on resume.
            local Save = require("models.save")
            local p = Player.new()
            Descent.markClassesOpen(p)
            local back = Save.restore(Save.snapshot(p))
            assert(back, "the snapshot should restore")
            assert(Descent.classesUnlocked(back),
                "the Roll closed again across a save -- `classesOpen` is not being persisted")
        end,
    },
}
