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
        -- ...AND THE CITY SAYS EXACTLY ONE THING. The plaza's whole coach was cut (2026-09-21) and this
        -- case pinned the silence; `ward_card` came back without the refusal (2026-09-23), so what is
        -- worth pinning is no longer the absence but the COUNT. One bubble, on one card, on one
        -- morning -- a second Locale.coach call out here is the corridor coming back one plate at a
        -- time, and it would arrive as a line nobody argued for rather than as a visible reversal.
        --
        -- The refusal itself is pinned by the case above, which reads openPanel: a bubble that turns a
        -- door down is a different failure from a second bubble, and they are asserted separately
        -- because either can come back without the other.
        name = "the city speaks once: one coach line, on the first morning's door",
        fn = function()
            local src = hubSource()
            local _, calls = src:gsub("Locale%.coach%(", "")
            assert(calls == 1,
                "states/hub.lua fetches " .. calls .. " coach lines; the plaza says one thing")
            assert(src:find('Locale.coach(CITY, "ward_card")', 1, true),
                "...and the one it says is the first morning's mending")
            -- IT IS GATED ON THE MORNING, not on the building being open. The Cathedral stands on the
            -- plaza forever; what makes this the first morning is the stage the mending room reads too.
            assert(src:find("if coachingMend() and not activePanel", 1, true),
                "the plaza's bubble is no longer gated on the coached morning")
            -- The three lines the bag still keeps for nobody. A host growing back for one of these is
            -- the thing the count above is really guarding, named so the failure says which.
            for _, id in ipairs({ "rift_card", "new_door", "board_card" }) do
                assert(not src:find('"' .. id .. '"', 1, true),
                    "states/hub.lua fields " .. id .. " again; that line is retired")
            end
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
