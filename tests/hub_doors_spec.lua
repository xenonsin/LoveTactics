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

return {
    {
        -- WHAT THE COACH BUBBLE READS. `description` was an authored field with no reader for most of
        -- its life -- three of the sixteen blueprints carried one and nothing drew it -- so a card
        -- added without one would have failed silently, which is the one failure mode a dead field
        -- reliably produces when it stops being dead.
        --
        -- Every CITY card, not every building: the seven shops are on their own board (states/houses.lua)
        -- and each already introduces itself in its keeper's own voice the first time it is opened
        -- (models/vendor_visit.lua). This board has no such scene, which is the whole reason it needs one.
        name = "every city card says what its room is for, in a line that fits the bubble",
        fn = function()
            local city = Building.list(Player.new(), { district = "city" })
            -- Seven, and it was eight until the Inn was deleted along with the wound toll it charged
            -- for (models/wound.lua). A floor rather than an exact count, so adding a card does not
            -- fail here -- what this guards is the layout coming back with a couple of doors because
            -- something upstream filtered wrongly, not the size of the ring.
            assert(#city >= 7, "the plaza should be laying out its whole ring, not a couple of cards")
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
            for _, b in ipairs(Building.list(p, { district = "city" })) do
                if b.locked then
                    assert(not contains(Building.unannounced(p), b.id),
                        b.id .. " is shut and must not be announced")
                end
            end
            assert(not Building.seenDoor(p, "forge"), "the Forge is shut on a fresh save, so unseeded")
        end,
    },
    {
        -- THE WHOLE LOOP, on a door whose gate is a single number: the company gets two floors down, it
        -- comes up, the Cafe is on the plaza and is owed its announcement -- once.
        --
        -- IT WAS THE INN, gated on the first wound, and both are deleted (models/wound.lua): a wound is
        -- a condition of the expedition now and the surface ends it, so there was no bone left for that
        -- building to set. The Cafe is the same shape -- shut on a fresh save, opened by a deed done
        -- underground -- which is all this case was ever about.
        name = "a door earned below is announced exactly once",
        fn = function()
            local p = seededPlayer()
            assert(not contains(Building.unannounced(p), "cafe"),
                "nobody has been down two floors yet")

            p.deepest = 2 -- the Cafe's gate (models/building.lua's unlockDepth)
            local owed = Building.unannounced(p)
            assert(contains(owed, "cafe"),
                "the second floor opens the Cafe, so the city owes an announcement for it: got "
                    .. table.concat(idsOf(owed), ", "))

            -- Spent by being WALKED INTO (states/hub.lua's openPanel), not by the bubble being read.
            Building.markSeen(p, "cafe")
            assert(not contains(Building.unannounced(p), "cafe"),
                "a door walked through is never announced again")
        end,
    },
    {
        -- THE SECOND BOARD, whose doors are announced by a DOT rather than by a bubble. The square is
        -- behind a card (states/houses.lua), so there is no plate on the plaza to pin a bubble to and
        -- nothing else on the screen that can say a shelf opened -- and a house opens on a class level,
        -- which is banked underground, so it opens with nobody standing there.
        --
        -- Read off the same ledger, which is the whole of why this case is here: the seeding walks both
        -- boards, or a company that has been shopping at the Colosseum for hours comes back to a dot on
        -- it. What the two boards do NOT share is how the mark is spent -- the plaza's on the coached
        -- card being walked into, the square's on the house being walked into (openHouse) -- and both
        -- are Building.markSeen.
        name = "a house that opens is unseen until it is walked into, and seeding covers the square",
        fn = function()
            local p = Player.new()
            -- One body a single class level into the fighter, which is the Colosseum's gate
            -- (data/buildings/colosseum.lua's unlockClassLevel, read through data/vendors/colosseum).
            p.roster = { { technique = { fighter = Class.classLevelCost(1) } } }
            Building.seedSeen(p)
            assert(Building.seenDoor(p, "colosseum"),
                "a house already open when the ledger was created was never news")

            -- ...and the one next door is still shut, so it is not seeded and cannot be a dot either:
            -- a locked plate never carries one (ui/building_map.lua).
            assert(not Building.seenDoor(p, "bastion"), "a shut house is not seeded")

            -- The knight climbs a rung while the company is below. Its shelf is open on the way home,
            -- and nothing has been shown to anybody.
            p.roster[1].technique.knight = Class.classLevelCost(1)
            local houses = Building.list(p, { district = "houses" })
            local bastion
            for _, h in ipairs(houses) do if h.id == "bastion" then bastion = h end end
            assert(bastion and not bastion.locked, "a class level opens that class's house")
            assert(not Building.seenDoor(p, "bastion"), "...and it is owed a dot")

            assert(Building.markSeen(p, "bastion"), "walking in spends the dot, and reports the flip")
            assert(Building.seenDoor(p, "bastion"), "a house walked into is never news again")
            assert(not Building.markSeen(p, "bastion"),
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
            -- Three at once: the Market (order 4, floor one), the Forge (order 6, floor four) and the
            -- Cafe (order 7, floor two). A company that went straight to four on its first trip comes
            -- back up owed all of them.
            p.deepest = 4

            local owed = Building.unannounced(p)
            assert(#owed >= 3, "three doors opened; got " .. table.concat(idsOf(owed), ", "))
            for i = 2, #owed do
                assert(owed[i - 1].order < owed[i].order,
                    "announcements are out of board order: " .. table.concat(idsOf(owed), ", "))
            end
            assert(owed[1].id == "market",
                "the Market sorts ahead of the Forge and the Cafe, which is board order; got "
                    .. table.concat(idsOf(owed), ", "))
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
            p.deepest = 2
            -- Both the doors two floors opened, walked into: the Market on floor one and the Cafe on
            -- floor two. The claim below is that a LOADED save owes nothing, so everything the trip grew
            -- has to have been spent before the round-trip -- one door left unwalked would make this
            -- case pass or fail on the leftover rather than on the ledger.
            Building.markSeen(p, "market")
            Building.markSeen(p, "cafe")

            local restored = Save.restore(Save.snapshot(p))
            assert(Building.seeded(restored), "a seeded ledger must come back seeded")
            assert(Building.seenDoor(restored, "cafe"), "...and remember the Cafe was walked into")
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
