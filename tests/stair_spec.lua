-- THE STAIR IS FOUND UNDER THE GUARDIAN, AND THE STAIRS RUN BOTH WAYS.
--
-- Two rules that arrived together because they are the same object seen from either side: what the way
-- down IS before it is a way down, and what happens when a company walks back up one.
--
-- THE NAME WAS THE LEAK. A floor's own end was called "The Stair Down — <Sin>", and a board names its
-- end on the marker and in the hovered readout -- so the moment the fog lifted off that place the player
-- had been told where the exit was and what it was for, before ever meeting the thing holding it. The
-- stair is meant to be what the guardian was STANDING ON: you find a body at the end of the road, you
-- put it down, and Descent.openStair renames the cell at that moment and only then.
--
-- THE DESCENT HAD ONE DIRECTION. The way up offered exactly one thing -- end the expedition -- so a
-- company that wanted to walk back to a pack it dropped two floors above had to climb out of the rift
-- and re-descend from the top. The floors are kept precisely so they can be walked again
-- (Descent.keepFloor); the only thing missing was the door back to them.

local Descent = require("models.descent")
local Player = require("models.player")

return {
    {
        name = "a floor's end is named for who stands on it, never for the stair beneath them",
        fn = function()
            local run = Descent.new(Player.new(), 909)
            for floor = 1, Descent.CIRCLE_FLOORS do
                run.floor = floor
                local mp = Descent.floorQuest(run, Player.new()).map
                local name = mp.objective and mp.objective.name
                assert(name and name ~= "", "floor " .. floor .. " has an unnamed end")
                -- The one string that must never appear before the fight: it is the name the cell TAKES
                -- once the guard is down (Descent.openStair), and reading it on the marker beforehand is
                -- the floor telling you where its exit is.
                assert(not tostring(name):find("Stair", 1, true), string.format(
                    "floor %d names its end %q -- that is the way out, announced before the fight",
                    floor, tostring(name)))
            end
        end,
    },
    {
        name = "the guard's name is the body's own, and the landing reports the same one",
        fn = function()
            -- Read off the blueprint rather than authored twice, so a circle that re-casts its guardian
            -- cannot end up with a marker naming one body and a landing card naming another.
            local Character = require("models.character")
            for _, sin in ipairs(Descent.SINS) do
                for _, isGeneral in ipairs({ true, false }) do
                    local band = isGeneral and sin.guardian or sin.minor
                    local def = Character.defs[band.lead]
                    assert(def, sin.id .. "'s " .. (isGeneral and "general" or "lieutenant")
                        .. " names a blueprint that does not exist: " .. tostring(band.lead))
                    assert(Descent.guardianName(sin, isGeneral) == def.name, string.format(
                        "%s: the marker would say %q and the body is %q", sin.id,
                        tostring(Descent.guardianName(sin, isGeneral)), tostring(def.name)))
                end
            end
        end,
    },
    {
        name = "the stair is only a stair once the guard is off it",
        fn = function()
            local cell = { x = 3, y = 4, encounter = { kind = "objective", name = "The Suppliant" },
                           cleared = true }
            Descent.openStair(cell)
            assert(cell.encounter.kind == "stair", "beating the guard opens the way down")
            assert(cell.encounter.name == "The Stair Down", "and the cell takes the stair's name then")
            assert(not cell.cleared, "the stair is a place that answers every time, not a spent stop")
        end,
    },
    {
        name = "a company can walk back up a floor, and comes out on the stair it came down by",
        fn = function()
            local run = Descent.new(Player.new(), 909)
            run.floor = 3
            -- The floor above, as the company left it: a board whose end is the stair they opened.
            Descent.keepFloor(run, 2, { objective = { x = 7, y = 5 }, cols = 10, rows = 10, cells = {} })

            local to = Descent.retreat(run)
            assert(to == 2, "the way up goes up ONE floor, not to the surface")
            assert(Descent.depth(run) == 2, "and the run is standing on it")
            assert(run.arriveAt and run.arriveAt.x == 7 and run.arriveAt.y == 5,
                "the company comes out on the stair it came down by, not at the floor's entrance -- "
                .. "arriving at the far end of ground already crossed is a teleport wearing a staircase")
        end,
    },
    {
        name = "walking up and back down is net zero on the tally",
        fn = function()
            -- Descending prunes the rift by one (Descent.advance). If coming back up were free, a
            -- company could walk a stair up and down between two floors and drive the count to zero for
            -- the price of the walking -- which would make the tally a purse rather than a statement
            -- about the state of the rift, the exact thing Descent.countBy's own header refuses.
            local p = Player.new()
            local run = Descent.new(p, 909)
            run.floor, p.count = 3, 10
            Descent.keepFloor(run, 2, { objective = { x = 1, y = 1 } })

            Descent.retreat(run, p)
            assert(Descent.count(p) == 11, "going up costs one, as going down pays one")
            Descent.advance(run, p)
            assert(Descent.count(p) == 10, "and a round trip is worth exactly nothing")
            assert(Descent.depth(run) == 3, "back where it started")
        end,
    },
    {
        name = "floor one's way up is the way OUT -- there is nothing above it to retreat to",
        fn = function()
            local run = Descent.new(Player.new(), 909)
            run.floor, run.count = 1, 4
            assert(Descent.retreat(run) == nil, "there is no floor zero")
            assert(Descent.depth(run) == 1, "and the company has not moved")
            assert(Descent.count(run) == 4, "nor been charged for a move it did not make")
        end,
    },
}
