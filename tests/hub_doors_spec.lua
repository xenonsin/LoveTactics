-- THE CITY COACHING A DOOR IT HAS JUST GROWN (models/building.lua's seenDoors block, states/hub.lua's
-- coachNextDoor).
--
-- Six of the nine cards on the plaza are shut on a fresh save and each opens on a deed done
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

-- A player standing in a city they have already looked at: the ledger seeded off the three cards a
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
        -- Every CITY card, not every building: the seven shops are on their own board (states/markets.lua)
        -- and each already introduces itself in its keeper's own voice the first time it is opened
        -- (models/vendor_visit.lua). This board has no such scene, which is the whole reason it needs one.
        name = "every city card says what its room is for, in a line that fits the bubble",
        fn = function()
            local city = Building.list(Player.new(), { district = "city" })
            assert(#city >= 8, "the plaza should be laying out its whole ring, not a couple of cards")
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
        -- THE WHOLE LOOP, on the door whose gate is a single flag: a wound is taken below, the company
        -- comes up, the Inn is on the plaza and is owed its announcement -- once.
        name = "a door earned below is announced exactly once",
        fn = function()
            local p = seededPlayer()
            assert(not contains(Building.unannounced(p), "the_inn"),
                "nobody has been carried up broken yet")

            p.wounded = true -- what Wound.mark leaves behind; the Inn's gate (models/building.lua)
            local owed = Building.unannounced(p)
            assert(contains(owed, "the_inn"),
                "the first wound opens the Inn, so the city owes an announcement for it: got "
                    .. table.concat(idsOf(owed), ", "))

            -- Spent by being WALKED INTO (states/hub.lua's openPanel), not by the bubble being read.
            Building.markSeen(p, "the_inn")
            assert(not contains(Building.unannounced(p), "the_inn"),
                "a door walked through is never announced again")
        end,
    },
    {
        -- BOARD ORDER, so a trip that opened two doors announces them in the order they are read rather
        -- than in whatever order pairs() happened to walk the registry -- which is not stable and would
        -- make the sequence differ between runs of the same save.
        name = "several doors opening at once are announced in board order",
        fn = function()
            local p = seededPlayer()
            p.wounded = true    -- the Inn (order 3)
            p.deepest = 4       -- the Cafe (order 7) and the Forge (order 6)

            local owed = Building.unannounced(p)
            assert(#owed >= 3, "three doors opened; got " .. table.concat(idsOf(owed), ", "))
            for i = 2, #owed do
                assert(owed[i - 1].order < owed[i].order,
                    "announcements are out of board order: " .. table.concat(idsOf(owed), ", "))
            end
            assert(owed[1].id == "the_inn", "the Inn sorts first of the three")
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
            p.wounded = true
            Building.markSeen(p, "the_inn")

            local restored = Save.restore(Save.snapshot(p))
            assert(Building.seeded(restored), "a seeded ledger must come back seeded")
            assert(Building.seenDoor(restored, "the_inn"), "...and remember the Inn was walked into")
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
