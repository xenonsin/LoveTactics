-- Tests for models/errand.lua -- the seven companion postings, and the two beats that recruit one.
--
-- THIS FILE REPLACED tests/errand_spec.lua, which pinned a ladder that no longer exists: every house
-- posted a line of errands and running them climbed that house's shelf, rung by rung. The houses are
-- classes now (docs/classes.md) and a class is climbed by a BODY playing its gear
-- (Discipline.classLevel), so there are no lines, no rungs bought with work, and no doors.
--
-- What survived the cut is the one thing the ladder carried that had nowhere else to go: a reason to go
-- back down, said out loud, with a name attached. Seven companions stand on the first floors, each asks
-- for one piece of work, and clearing it is how they join.

local Errand = require("models.errand")
local Descent = require("models.descent")
local Player = require("models.player")
local Quest = require("models.quest")
local Save = require("models.save")
local Vendor = require("models.vendor")

local function company(done)
    local p = Player.new()
    p.completedQuests = done or {}
    return p
end

local function houses()
    local ids = {}
    for vendorId in pairs(Errand.houses()) do ids[#ids + 1] = vendorId end
    table.sort(ids)
    return ids
end

return {
    {
        -- The whole roster arrives this way, so a class that names a companion and cannot post an ask
        -- for them is a body that can never be recruited -- and it would fail silently, because a
        -- posting that does not exist simply is not seated.
        name = "every class with a companion posts an ask that exists and can be fought",
        fn = function()
            local seen = 0
            for vendorId, def in pairs(Vendor.defs) do
                if def.companion then
                    local ask = Errand.opener(vendorId)
                    assert(ask, vendorId .. " names " .. def.companion .. " but posts no ask")
                    local qdef = Quest.defs[ask]
                    assert(qdef and qdef.map and qdef.map.objective,
                        ask .. " has no objective, so no floor can seat it")
                    seen = seen + 1
                end
            end
            assert(seen == 7, "seven companions, seven postings -- found " .. seen)
        end,
    },
    {
        -- The join route. Every posting hands its companion over through `rewardCharacter`, which is
        -- the path Quest.complete already walked for Saber -- Player.recruit runs before the outro, so
        -- the join banner and their first words land in one beat.
        --
        -- Rowan is the one exemption and it is authored rather than incidental: she is the player's
        -- bodyguard from the prologue, so she is already in the company before the Bastion's posting is
        -- ever met, and granting her again would be a reward nobody can receive.
        name = "a posting hands over the companion it was met with",
        fn = function()
            for _, vendorId in ipairs(houses()) do
                local def = Quest.defs[Errand.opener(vendorId)]
                local companion = Vendor.defs[vendorId].companion
                if companion == "character_rowan" then
                    assert(def.rewardCharacter == nil,
                        "Rowan joins in the prologue; her posting must not re-grant her")
                else
                    assert(def.rewardCharacter == companion,
                        vendorId .. " posts for " .. tostring(companion)
                            .. " but pays " .. tostring(def.rewardCharacter))
                end
            end
        end,
    },
    {
        name = "an ask is outstanding until it is run, and finishing it is what joins them",
        fn = function()
            local vendorId = houses()[1]
            local ask = Errand.opener(vendorId)

            assert(not Errand.doorOpen(company(), vendorId), "nothing is done on a fresh save")
            assert(Errand.doorOpen(company({ [ask] = true }), vendorId),
                "running the ask is the whole of the question")
        end,
    },
    {
        -- The second beat. Accepting marks the ask on the floor the companion was met on and puts a row
        -- on the checklist; until then there is nothing outstanding at all, because talking is free.
        name = "accepting an ask marks it on the floor it was met on, and says so until it is done",
        fn = function()
            local p = company()
            local vendorId = houses()[1]
            local ask = Errand.opener(vendorId)

            assert(#Errand.open(p) == 0, "a company that has met nobody carries nothing")

            Errand.accept(p, ask, 2)
            local open = Errand.open(p)
            assert(#open == 1 and open[1].id == ask, "the ask is outstanding once it is taken on")
            assert(open[1].floor == 2, "and it remembers which floor to look on")
            assert(Errand.floorFor(p, vendorId) == 2, "which is what the readout asks for")

            local onTwo = Errand.onFloor(p, 2)
            assert(#onTwo == 1 and onTwo[1].id == ask, "floor two carries it")
            assert(#Errand.onFloor(p, 3) == 0, "and no other floor does")

            -- Finished is finished: the mark comes off the board rather than lingering as a row nobody
            -- can clear.
            p.completedQuests[ask] = true
            assert(#Errand.open(p) == 0, "a finished ask is not outstanding")
            assert(#Errand.onFloor(p, 2) == 0, "and its floor no longer carries it")
        end,
    },
    {
        name = "an accepted ask survives a save, floor and all",
        fn = function()
            local p = company()
            local ask = Errand.opener(houses()[1])
            Errand.accept(p, ask, 2)

            -- Through the encoder rather than the snapshot table alone: what has to survive is the
            -- written file, and a field that is snapshotted but not serialized would pass the shorter
            -- test and lose the floor on disk.
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
            local open = Errand.open(back)
            assert(#open == 1 and open[1].id == ask and open[1].floor == 2,
                "an ask whose floor did not survive is an ask the player has to remember")
        end,
    },
    {
        -- All seven are dealt into the first circle, and this is a fact about CAPACITY as much as about
        -- pacing: a shallow floor carves a handful of dead ends and the stair takes one, so seven
        -- postings on floor one would be seating eight ends in seven spurs and the generator would start
        -- degrading them onto shared ground.
        name = "every companion is met in the first circle, and no floor carries all of them",
        fn = function()
            local run = { seed = 12345 }
            local seen, byFloor = {}, {}
            for floor = 1, Descent.CIRCLE_FLOORS do
                local here = Descent.openersAt(run, floor)
                byFloor[floor] = #here
                for _, vendorId in ipairs(here) do
                    assert(not seen[vendorId], vendorId .. " is posted on two floors")
                    seen[vendorId] = floor
                end
            end

            local n = 0
            for _ in pairs(seen) do n = n + 1 end
            assert(n == 7, "all seven doors are dealt, got " .. n)

            for floor, count in pairs(byFloor) do
                assert(count <= 4, "floor " .. floor .. " carries " .. count .. " postings, which is a queue")
                if count > 0 then
                    assert(floor <= Descent.OPENER_FLOORS,
                        "a posting outside the first circle pays opening-rack gear at depth")
                end
            end
        end,
    },
    {
        -- Derived from the seed, never stored: a resume rebuilds a floor from (seed, depth) alone, and a
        -- stored order is a second copy that can disagree with it.
        name = "the deal is a function of the seed, so a resumed run meets the same bodies",
        fn = function()
            local a = Descent.openersAt({ seed = 777 }, 1)
            local b = Descent.openersAt({ seed = 777 }, 1)
            assert(#a == #b, "the same seed dealt a different count")
            for i = 1, #a do assert(a[i] == b[i], "the same seed dealt a different house at " .. i) end
        end,
    },
    {
        -- THE BUG THIS PINS was live and invisible: agreeing to a posting set `errandAnswered` on the
        -- DOOR -- a fact about that cell, which stops the same question being asked twice -- and wrote
        -- nothing to the run. So a company that had said yes carried no record of it: no checklist row,
        -- nothing in the shop's list of outstanding asks, and nowhere at all that said what they had
        -- agreed to or which floor it was on.
        name = "an unaccepted posting is not on the worklist, and accepting is what puts it there",
        fn = function()
            local p = company()
            local ask = Errand.opener(houses()[1])

            assert(Errand.unaskedPosting(p, ask),
                "a posting the company has not agreed to is not work they are carrying")

            Errand.accept(p, ask, 1)
            assert(not Errand.unaskedPosting(p, ask), "saying yes is what makes it theirs")

            -- ...and it stops being outstanding once it is run, rather than sitting on the list forever.
            p.completedQuests[ask] = true
            assert(not Errand.unaskedPosting(p, ask), "a finished posting is not unasked either")
        end,
    },
    {
        -- An ordinary quest is not a posting and must never be filtered off the worklist by this rule:
        -- the gate exists for the seven asks a companion makes, and a rule that swept up anything else
        -- would hide real work from the checklist with nothing on screen to say why.
        name = "the worklist gate only ever hides a companion's own ask",
        fn = function()
            local p = company()
            assert(not Errand.unaskedPosting(p, "quest_no_such_thing"),
                "an id that is nobody's posting is not gated")
            assert(not Errand.unaskedPosting(p, nil), "and neither is nothing at all")
        end,
    },
}
