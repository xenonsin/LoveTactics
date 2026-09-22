-- THE PLAZA'S DOORS: every card opens, and none of them speaks.
--
-- This file used to be about the opposite. The city COACHED a door it had just grown -- a bubble on the
-- card carrying the blueprint's own sentence, with every other card refused until that one had been
-- walked into -- and most of what was asserted here was the ledger behind it (`player.seenDoors`):
-- coaching what was always there, coaching the same door twice, forgetting a door across a save.
--
-- All of it is cut (2026-09-21, states/hub.lua's header). A plaza of nine plates whose whole job is to
-- be a place you choose in does not get to point at one plate and turn the other eight down. So what is
-- left to hold is the absence -- there is no bubble and no refusal out here -- plus the one thing the
-- refusal took with it when it went, which is the routing bug below.
--
-- Provable headless: no window is opened and no frame drawn. The routes are read out of the source,
-- which is what states/hub.lua allows -- openPanel is a local in a state file and there is no window
-- here to press a card in, but the failures below are ROUTES rather than behaviours, and a route is
-- legible in the text.

local Building = require("models.building")
local Player = require("models.player")

local function hubSource()
    return assert(love.filesystem.read("states/hub.lua"), "states/hub.lua is readable")
end

-- openPanel's body, sliced out between its own header and the next top-level local function. Nested
-- `end`s make matching the function's own close unreliable; the next declaration is unambiguous.
local function openPanelBody(src)
    local from = assert(src:find("local function openPanel", 1, true), "openPanel is still named that")
    local to = src:find("\nlocal function ", from + 1, true) or #src
    return src:sub(from, to)
end

return {
    {
        -- A DOOR OPENS THROUGH THE ROOM'S OWN SCENE, and this pins the bug that forgetting it caused.
        -- openPanel had two ways out for most of its life: the coached branch, which refused every card
        -- but the one the bubble was on, and free play. Free play went through launchVendor -- the
        -- greeting, the room's own `intro`, the companion that scene `grants` -- and the coached branch
        -- called launchPanel directly, because for its whole life the only stage there was the hall's,
        -- a room with nothing to say on the way in.
        --
        -- Then the WARD took a stage and inherited that path. So the one coached door in the game that
        -- hands over a companion was the one door that skipped the code which hands one over: the scene
        -- never played, Xin never joined, and the room opened straight onto its two rows with nobody
        -- standing in it. Every ledger involved was correct and the player still never met her.
        --
        -- The coached branch is gone and the trap is not: this stays because the next second branch
        -- added here would be added by somebody who does not know that story.
        name = "a door opens through launchVendor, so the room's own scene still plays",
        fn = function()
            local body = openPanelBody(hubSource())
            assert(body:find("launchVendor(building)", 1, true),
                "openPanel must route doors through launchVendor")
            assert(not body:find("launchPanel(building)", 1, true),
                "...on EVERY branch: a door that calls launchPanel directly swallows its "
                .. "building's `intro` and the companion the scene grants")
        end,
    },
    {
        -- NO CARD IS REFUSED. openPanel is the activation seam the building map calls with whatever was
        -- pressed, and the whole of it is now "open that one". A guard in here -- on a tutorial stage, a
        -- coached id, anything -- is the corridor coming back, so this reads the body rather than the
        -- behaviour: an early `return` before launchVendor is a card the player pressed and nothing
        -- happened to.
        name = "the plaza refuses no card: every press opens the door it landed on",
        fn = function()
            local body = openPanelBody(hubSource())
            assert(not body:find("then return end", 1, true),
                "openPanel turns a press down; the plaza does not do that any more")
            -- One call and one line of work. A cheap floor rather than a parse: whatever grows here
            -- later, it should not be a branch over which building was pressed.
            local _, calls = body:gsub("launchVendor%(", "")
            assert(calls == 1, "openPanel should reach launchVendor once, unconditionally")
        end,
    },
    {
        -- ...AND NOTHING OUT HERE SPEAKS. The city drew a coach bubble from hub.draw for as long as it
        -- had a stage to draw one for, and the widget is still in the tree -- the Gate's descend row
        -- and the Ward's rows wear it (ui/coach_bubble.lua). What must not come back is the plaza
        -- wearing one, so this pins the absence at the file that would have to import it.
        name = "the city itself draws no coach bubble",
        fn = function()
            local src = hubSource()
            assert(not src:find("CoachBubble", 1, true),
                "states/hub.lua is drawing a coach bubble again; the plaza coaches nothing")
            -- ...and it asks the hint bag for nothing. The bag's own NAME survives in a comment
            -- here, which is why this reads the call rather than the string: Locale.coach is the one
            -- way a bubble's words are fetched, and the city makes no such call.
            assert(not src:find("Locale.coach", 1, true),
                "states/hub.lua is fetching a coach line; nothing out here speaks")
        end,
    },
    {
        -- THE LEDGER IS GONE WITH THE COACH. `player.seenDoors` existed for one purpose -- keeping a
        -- grown door's announcement to once -- and five functions on models/building.lua served it.
        -- A save may still carry the field and nothing reads it; what this guards is the other
        -- direction, a reader growing back without the announcement that justified it.
        name = "the shown-door ledger is not quietly reinstated",
        fn = function()
            for _, name in ipairs({ "seeded", "seenDoor", "markSeen", "seedSeen", "unannounced" }) do
                assert(Building[name] == nil,
                    "Building." .. name .. " is back: the door ledger has no reader to earn it")
            end
        end,
    },
    {
        -- THE BOARD STILL LAYS OUT WHOLE, which is the one thing the deleted cases were also asserting
        -- underneath their own subject. Nine: the Rift, the Armory and the seven houses. A floor rather
        -- than an exact count, so adding a card does not fail here -- what this catches is the layout
        -- coming back with a couple of doors because something upstream filtered wrongly.
        name = "the plaza lays out its whole ring",
        fn = function()
            local city = Building.list(Player.new())
            assert(#city >= 9, "the plaza should be laying out its whole ring, not a couple of cards")
            local seen = {}
            for _, b in ipairs(city) do
                assert(not seen[b.id], b.id .. " is on the board twice")
                seen[b.id] = true
            end
            assert(seen.the_gate and seen.armory,
                "the stair and the Armory are open on a fresh save; they are the city's two doors")
        end,
    },
}
