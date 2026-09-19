-- THE CITY COACHING A DOOR IT HAS JUST GROWN (models/building.lua's seenDoors block, states/hub.lua's
-- coachNextDoor).
--
-- Six of the eight cards on the plaza are shut on a fresh save and each opens on a deed done
-- underground. The player comes up, a card that was three question marks is a name, and without this
-- nothing says it happened or what the room is for. So the city puts a bubble on the card -- the same
-- one the first visit puts on the hall and the stair -- and refuses every other card until it has been
-- walked into.
--
-- The whole of that is DATA plus a ledger, which is why it is provable headless: no window is opened
-- and no frame drawn. What is asserted here is what the bubble reads (every city card carries the
-- sentence, and it fits), and the three ways the ledger can be wrong -- coaching what was always there,
-- coaching the same door twice, and forgetting a door across a save.

local Building = require("models.building")
local Class = require("models.class")
local Player = require("models.player")
local Save = require("models.save")

-- How long a door's sentence may be. The bubble is 240px at a 13px body face and draws the card's name
-- ahead of this (states/hub.lua's doorText), so the budget is what is left over -- roughly four lines.
local BUBBLE_MAX = 90

local function idsOf(list)
    local ids = {}
    for _, b in ipairs(list) do ids[#ids + 1] = b.id end
    return ids
end

local function contains(list, id)
    for _, b in ipairs(list) do if b.id == id then return true end end
    return false
end

-- A player standing in a city they have already looked at: the ledger seeded off the two cards a
-- fresh save opens with, and nothing owed an announcement.
local function seededPlayer()
    local p = Player.new()
    Building.seedSeen(p)
    return p
end

-- The one seam in states/hub.lua this file can reach, read as text. openPanel is a local in a state
-- file and there is no window here to press a card in, but the failure below is a ROUTE rather than a
-- behaviour -- which branch of a two-branch function a door leaves through -- and a route is legible in
-- the source.
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
        -- A COACHED DOOR IS STILL A DOOR, and this pins the bug that forgetting it caused. openPanel has
        -- two ways out: the coached branch, which refuses every card but the one the bubble is on, and
        -- free play. Free play goes through launchVendor -- the greeting, the room's own `intro`, the
        -- companion that scene `grants` -- and the coached branch used to call launchPanel directly,
        -- because for its whole life the only stage here was the hall's, a room with nothing to say on
        -- the way in.
        --
        -- Then the WARD took a stage (INTRO_STAGES.ward) and inherited that path. So the one coached
        -- door in the game that hands over a companion was the one door that skipped the code which
        -- hands one over: the scene never played, Xin never joined, and the room opened straight onto
        -- its two rows with nobody standing in it. Every ledger involved was correct -- the flag was
        -- unspent, the blueprint carried `intro` and `grants` -- and the player still never met her,
        -- which is why the fact asserted here is the CALL and not the data around it.
        name = "a coached door opens through launchVendor, so the room's own scene still plays",
        fn = function()
            local body = openPanelBody(hubSource())
            assert(body:find("launchVendor(building)", 1, true),
                "openPanel must route doors through launchVendor")
            assert(not body:find("launchPanel(building)", 1, true),
                "...on EVERY branch: a coached door that calls launchPanel directly swallows its "
                .. "building's `intro` and the companion the scene grants")
        end,
    },
    {
        -- WHAT THE COACH BUBBLE READS. `description` was an authored field with no reader for most of
        -- its life -- three of the sixteen blueprints carried one and nothing drew it -- so a card
        -- added without one would have failed silently, which is the one failure mode a dead field
        -- reliably produces when it stops being dead.
        --
        -- EVERY CARD, and there is one board now. The seven houses stood on a square of their own and
        -- each introduced itself in its keeper's voice the first time it was opened
        -- (models/vendor_visit.lua) -- they are on the plaza with the rest, so they are coached the way
        -- the rest are, and they need the sentence too.
        name = "every city card says what its room is for, in a line that fits the bubble",
        fn = function()
            local city = Building.list(Player.new())
            -- Nine: the Rift, the Armory and the seven houses. A floor rather than an exact count, so
            -- adding a card does not fail here -- what this guards is the layout coming back with a
            -- couple of doors because something upstream filtered wrongly, not the size of the ring.
            assert(#city >= 9, "the plaza should be laying out its whole ring, not a couple of cards")
            for _, b in ipairs(city) do
                local d = b.description
                assert(type(d) == "string" and d ~= "",
                    b.id .. " has no description, so its card would be coached by name alone")
                -- A NAME IS NOT A DESCRIPTION. The card already carries the name; what this field owes
                -- the player is the clause that makes the room worth walking into, so a fragment
                -- rewriting the sign is the failure this catches.
                assert(#d >= 30 and d:match("%.%s*$"),
                    b.id .. " describes its door in less than a sentence")
                -- ...AND IT HAS TO FIT. The bubble is 240px wide at a 13px body face beside a key cap
                -- (ui/coach_bubble.lua), and it draws the card's NAME in front of this. The intro's own
                -- two lines are the calibration: the Crossing's is 51 characters all in, and lands
                -- as two comfortable lines. This cap leaves room for a name and about four.
                assert(#d <= BUBBLE_MAX, string.format(
                    "%s's description is %d characters; a coach bubble holds about %d, and the card's " ..
                    "name goes in front of it", b.id, #d, BUBBLE_MAX))
            end
        end,
    },
    {
        -- NOTHING ALREADY STANDING IS NEWS. The ledger is nil until the city is first looked at, and an
        -- empty table is deliberately NOT the same state -- an older save carries exactly nil, and
        -- treating that as "has seen nothing" would march a company that has been using the Forge for
        -- hours back through an announcement for it.
        name = "an unlooked-at city is owed nothing, and seeding records what is already open",
        fn = function()
            local p = Player.new()
            assert(not Building.seeded(p), "a fresh player has not looked at the city yet")
            assert(#Building.unannounced(p) == 0,
                "an unseeded ledger must announce nothing: everything standing was there on arrival")

            Building.seedSeen(p)
            assert(Building.seeded(p), "seeding creates the ledger")
            assert(#Building.unannounced(p) == 0, "...and leaves nothing owed an announcement")

            -- The two the plaza opens with. One is the first visit's own business (states/hub.lua's
            -- INTRO_STAGES coaches the stair); the other would be a third thing to press before the
            -- player has pressed anything.
            --
            -- IT WAS THREE, and the third was `hiring_hall` -- the Crossing, coached alongside the stair
            -- by an INTRO_STAGES entry that no longer exists. The building is deleted with the pull.
            for _, id in ipairs({ "the_gate", "armory" }) do
                assert(Building.seenDoor(p, id), id .. " is open on a fresh save and must be seeded")
            end
            -- ...and a seeded ledger is never EMPTY, which is what lets the save drop an empty one and
            -- still tell "unseeded" from "seeded".
            local n = 0
            for _ in pairs(p.seenDoors) do n = n + 1 end
            assert(n >= 2, "a seeded ledger must be non-empty, or nil and empty stop being different")
        end,
    },
    {
        -- A SHUT DOOR IS NOT NEWS EITHER. The queue is the doors that OPENED, so a card still behind its
        -- gate must never reach the announcement -- which would name the room the card exists to
        -- withhold, on a plate the player cannot press.
        name = "a door still behind its gate is never announced",
        fn = function()
            local p = seededPlayer()
            for _, b in ipairs(Building.list(p)) do
                if b.locked then
                    assert(not contains(Building.unannounced(p), b.id),
                        b.id .. " is shut and must not be announced")
                end
            end
            assert(not Building.seenDoor(p, "bastion"),
                "the Bastion is shut on a fresh save -- no trips home -- so unseeded")
        end,
    },
    {
        -- THE WHOLE LOOP, on a door whose gate is a single number: the company gets two floors down, it
        -- comes up, the Lodge is on the plaza and is owed its announcement -- once.
        --
        -- IT IS A DOOR OPENED BY A ROOM. The Cafe stood here as a card of its own; the supper is a line
        -- on Hunter's Lodge's desk now (models/offer.lua) and carried its floor-two gate with it, so the
        -- house's plate arrives on the morning the supper does. The shape this case is about -- shut on
        -- a fresh save, opened by a deed done underground, announced once -- is unchanged.
        name = "a door earned below is announced exactly once",
        fn = function()
            local p = seededPlayer()
            assert(not contains(Building.unannounced(p), "hunters_lodge"),
                "nobody has been down two floors yet")

            p.runsStarted = 2 -- the supper's gate (data/buildings/hunters_lodge.lua)
            local owed = Building.unannounced(p)
            assert(contains(owed, "hunters_lodge"),
                "the second floor opens the Lodge, so the city owes an announcement for it: got "
                    .. table.concat(idsOf(owed), ", "))

            -- Spent by being WALKED INTO (states/hub.lua's openPanel), not by the bubble being read.
            Building.markSeen(p, "hunters_lodge")
            assert(not contains(Building.unannounced(p), "hunters_lodge"),
                "a door walked through is never announced again")
        end,
    },
    {
        -- A HOUSE OPENS WHILE THE COMPANY IS UNDERGROUND -- the trip that opens it is one it spends in
        -- the rift -- so its plate arrives with nobody standing in the city, and the ledger is the only
        -- thing that can say so on the way home.
        --
        -- The seeding has to cover it, which is the whole of why this case is here: a company that has
        -- been shopping at the Undercroft for hours must not come back to a dot on it.
        name = "a house that opens is unseen until it is walked into, and seeding covers it",
        fn = function()
            local p = Player.new()
            -- One trip home, which is the Undercroft's gate (data/buildings/undercroft.lua).
            p.runsStarted = 1
            Building.seedSeen(p)
            assert(Building.seenDoor(p, "undercroft"),
                "a house already open when the ledger was created was never news")

            -- ...and the one after it is still shut, so it is not seeded and cannot be a dot either:
            -- a locked plate never carries one (ui/building_map.lua).
            assert(not Building.seenDoor(p, "hunters_lodge"), "a shut house is not seeded")

            -- The company goes down again. The Lodge is open on the way home, and nothing has been
            -- shown to anybody.
            p.runsStarted = 2
            local lodge
            for _, h in ipairs(Building.list(p)) do if h.id == "hunters_lodge" then lodge = h end end
            assert(lodge and not lodge.locked, "a second trip opens the Lodge")
            assert(not Building.seenDoor(p, "hunters_lodge"), "...and it is owed a dot")

            assert(Building.markSeen(p, "hunters_lodge"), "walking in spends the dot, and reports the flip")
            assert(Building.seenDoor(p, "hunters_lodge"), "a house walked into is never news again")
            assert(not Building.markSeen(p, "hunters_lodge"),
                "...so the second walk saves nothing, which is what the return value is for")
        end,
    },
    {
        -- BOARD ORDER, so a trip that opened two doors announces them in the order they are read rather
        -- than in whatever order pairs() happened to walk the registry -- which is not stable and would
        -- make the sequence differ between runs of the same save.
        name = "several doors opening at once are announced in board order",
        fn = function()
            local p = seededPlayer()
            -- Four at once: the Bastion (order 4, the forge on trip three), Hunter's Lodge (order 6,
            -- the supper on two), the Undercroft (order 7, the town counter on one) and the Arcanum
            -- (order 9, the book on four).
            --
            -- A COMPANY CANNOT ACTUALLY REACH THIS STATE ANY MORE, and that is the point of the clock:
            -- trips climb one at a time, so the city hands over one door per homecoming and this queue
            -- never holds four. It is forced here anyway, because what this case pins is the ORDER the
            -- queue reports in, and that has to keep working for whatever does stack up.
            p.runsStarted = 4

            local owed = Building.unannounced(p)
            assert(#owed >= 4, "four doors opened; got " .. table.concat(idsOf(owed), ", "))
            for i = 2, #owed do
                assert(owed[i - 1].order < owed[i].order,
                    "announcements are out of board order: " .. table.concat(idsOf(owed), ", "))
            end
            assert(owed[1].id == "bastion",
                "the Bastion sorts ahead of the Lodge, the Undercroft and the Arcanum, which is board "
                    .. "order; got " .. table.concat(idsOf(owed), ", "))
        end,
    },
    {
        -- ACROSS A SAVE. The ledger is the only thing keeping the announcement to once, and it is a
        -- table on the player -- so a round-trip that dropped it would re-announce every door the
        -- company owns on the next load, and one that rebuilt nil as `{}` would re-announce them on an
        -- older save. Both directions are pinned.
        name = "the shown-door ledger survives a save, and an older save stays unseeded",
        fn = function()
            local p = seededPlayer()
            p.runsStarted = 2
            -- EVERY door two trips opened, walked into. The claim below is that a LOADED save owes
            -- nothing, so everything the trips grew has to have been spent before the round-trip --
            -- one door left unwalked would make this case pass or fail on the leftover rather than
            -- on the ledger.
            for _, b in ipairs(Building.unannounced(p)) do Building.markSeen(p, b.id) end

            local restored = Save.restore(Save.snapshot(p))
            assert(Building.seeded(restored), "a seeded ledger must come back seeded")
            assert(Building.seenDoor(restored, "hunters_lodge"),
                "...and remember the Lodge was walked into")
            assert(Building.seenDoor(restored, "the_gate"), "...and everything it was seeded with")
            assert(#Building.unannounced(restored) == 0,
                "a loaded save owes no announcement for a door it has already shown")

            -- A save written before any of this existed: no ledger at all. It must stay nil, so the hub
            -- seeds it off what that company has already earned instead of announcing all of it.
            local old = Save.snapshot(p)
            old.seenDoors = nil
            local loaded = Save.restore(old)
            assert(not Building.seeded(loaded),
                "an older save has no ledger and must not be handed an empty one")
            assert(#Building.unannounced(loaded) == 0, "...so it is owed nothing until the hub seeds it")
        end,
    },
}
