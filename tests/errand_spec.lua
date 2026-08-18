-- Tests for models/errand.lua -- the small work a house asks for, and the second gate on its shelf.
--
-- A house opens its DOOR on its own first errand, found on a floor (tests/hub_spec.lua pins that half).
-- What that does not do is hand over its catalogue: the shelf still climbs a rung at a time and each
-- rung is bought by running another errand. So stock is gated twice -- by the floor reached, and by the
-- work done -- and this file is the second of those.
--
-- The errands ARE the campaign's parked quests, re-seated (see the module header), so most of what is
-- checked here is that the re-reading is faithful: the ordering is the slot order, the ledger is the one
-- the shelf already reads, and a finished errand opens stock through the machinery that existed.

local Errand = require("models.errand")
local Player = require("models.player")
local Quest = require("models.quest")
local Save = require("models.save")
local Vendor = require("models.vendor")

-- A company whose door at `vendorId` is open (or not) and which has gone `deepest` floors down. The
-- door is the house's OPENER having been run -- its first errand, found on a floor (models/errand.lua).
local function company(vendorId, doorOpen, deepest)
    local p = Player.new()
    p.completedQuests = {}
    if doorOpen then p.completedQuests[Errand.opener(vendorId)] = true end
    p.descentRun = { cleared = deepest or 0 }
    return p
end

return {
    { name = "a house asks in slot order, and only for its own work", fn = function()
        -- `pairs` over the quest registry is unspecified, so an unsorted list would have a house ask for
        -- its seventh errand first on some machines and not others -- and the slot number IS the order,
        -- which is the one piece of the campaign's chain that still carries meaning.
        for _, vendorId in ipairs({ "bastion", "cathedral", "arcanum" }) do
            local ids = Errand.forVendor(vendorId)
            assert(#ids > 0, vendorId .. " has no errands at all")
            for i = 2, #ids do
                assert(ids[i - 1] < ids[i], vendorId .. " is not in slot order at " .. i)
            end
            for _, id in ipairs(ids) do
                assert(Quest.defs[id].sponsor == vendorId,
                    id .. " is on " .. vendorId .. "'s list but is not theirs")
            end
        end
    end },

    { name = "three gates: the door, the line, and how deep you have been", fn = function()
        local v = "bastion"

        -- The door first. A house whose opener has not been run asks for nothing, however deep the
        -- company has gone -- there is nowhere to ask, because asking happens inside the shop.
        local shut = company(v, false, 40)
        assert(Errand.offered(shut, v, 40) == nil, "a house whose door is shut asks for nothing")

        -- ...and once it is open, the FLOOR still gates it. A company that has run the opener but only
        -- gone a floor deep is not being handed the second rung.
        local shallow = company(v, true, 0)
        assert(Errand.offered(shallow, v, 0) == nil, "a house asks nothing of a company that has not gone down")

        local deep = company(v, true, Errand.FLOORS_PER_RUNG * 2)
        local next2 = Errand.offered(deep, v, Errand.FLOORS_PER_RUNG * 2)
        assert(next2, "an open door and enough depth should produce an errand")
        -- The SECOND of the line, and that is the door model rather than an off-by-one: the opener is
        -- the first, it was run on a floor, and running it is what put this shop on the board at all.
        assert(next2 == Errand.forVendor(v)[2], "and it is the second of the line -- the opener is spent")

        -- The line runs out. A house that has been run dry asks for nothing rather than looping.
        local finished = company(v, true, 99)
        for _, id in ipairs(Errand.forVendor(v)) do finished.completedQuests[id] = true end
        assert(Errand.offered(finished, v, 99) == nil, "a finished line asks for nothing")
    end },

    { name = "each rung asks the company to have gone deeper than the last", fn = function()
        local v = "bastion"
        local p = company(v, true, 99)
        local last = 0
        for i = 1, 4 do
            local floor = Errand.floorFor(p, v)
            assert(floor > last, "rung " .. i .. " asks for no more depth than the one before it")
            last = floor
            Errand.complete(p, Errand.next(p, v))
        end
    end },

    { name = "an errand knows which floor to find it on, and says so until it is done", fn = function()
        -- The floor is the whole reason the open list exists: an errand whose location the player has to
        -- remember is a chore the game could have spared them.
        local v = "bastion"
        local p = company(v, true, 10)
        local id = Errand.offered(p, v, 10)

        assert(#Errand.open(p) == 0, "nothing is open before it is taken on")
        Errand.accept(p, id, 6)

        local open = Errand.open(p)
        assert(#open == 1 and open[1].id == id, "the errand is open once taken on")
        assert(open[1].floor == 6, "and it remembers the floor it was seated on")
        assert(open[1].def, "and carries its blueprint, so a list can name it")

        assert(#Errand.onFloor(p, 6) == 1, "it is seated on its own floor")
        assert(#Errand.onFloor(p, 5) == 0, "and on no other")

        assert(Errand.complete(p, id), "finishing it reports the change")
        assert(#Errand.open(p) == 0, "and it stops being open")
        assert(#Errand.onFloor(p, 6) == 0, "and stops being seated")
        assert(not Errand.complete(p, id), "finishing it twice changes nothing")
    end },

    { name = "a finished errand opens the shelf by the path the shelf already read", fn = function()
        -- THE LEDGER IS THE ONE THAT EXISTED. Stock is gated on Quest.sponsorProgress, which counts
        -- completed quests per sponsor -- so an errand completes by writing `completedQuests`, and the
        -- shop opens with no second tally that could disagree with the first.
        local v = "bastion"
        local p = company(v, true, 99)
        local before = Vendor.stock(v, Quest.sponsorProgress(p, v))
        local openBefore = 0
        for _, e in ipairs(before) do if not e.locked then openBefore = openBefore + 1 end end

        Errand.complete(p, Errand.next(p, v))
        assert(Quest.sponsorProgress(p, v) >= 1, "the shelf's own counter moved")

        local after = Vendor.stock(v, Quest.sponsorProgress(p, v))
        local openAfter = 0
        for _, e in ipairs(after) do if not e.locked then openAfter = openAfter + 1 end end
        assert(openAfter > openBefore,
            "running an errand opened nothing: " .. openBefore .. " -> " .. openAfter)
    end },

    { name = "open errands survive a save, floor and all", fn = function()
        local v = "bastion"
        local p = company(v, true, 10)
        local id = Errand.offered(p, v, 10)
        Errand.accept(p, id, 7)

        local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
        assert(back, "the company round-trips")
        local open = Errand.open(back)
        assert(#open == 1 and open[1].id == id, "the errand is still open")
        assert(open[1].floor == 7, "on the floor it was seated on -- the thing the shop has to print")

        -- ...and a company that has taken none on restores with none rather than a nil the list would
        -- have to guard against.
        local clean = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(Player.new()), 0)))
        assert(clean.errands and #Errand.open(clean) == 0, "an unburdened company restores unburdened")
    end },

    { name = "every errand is something a floor can actually seat", fn = function()
        -- An errand becomes an objective on a descent floor (models/descent.lua's floorObjectives), and
        -- an objective needs a composition and a win condition. A quest whose map has neither would
        -- generate a board with an end that cannot be fought -- which is not a crash, it is a floor the
        -- player walks to the middle of and cannot finish.
        for _, vendorId in ipairs({ "bastion", "cathedral", "arcanum", "colosseum",
                                    "hunters_lodge", "undercroft", "alchemist" }) do
            for _, id in ipairs(Errand.forVendor(vendorId)) do
                local obj = Quest.defs[id].map.objective
                assert(obj, id .. " has no objective to seat")
                assert(obj.composition, id .. " has no composition: nothing to fight")
                assert(obj.win and obj.win.type, id .. " has no win condition: nothing to finish")
            end
        end
    end },

    { name = "an opener thanks you in the house's own voice, and its counter greets you in the same one", fn = function()
        -- THE SHAPE OF MEETING A HOUSE. Its first job is lying on a floor with nobody to introduce it
        -- (Errand.opener), so the only two moments the house gets to speak are the thanks straight after
        -- that fight and the greeting the first time you walk into the shop it opened. Both have to be
        -- the SAME voice or the player meets two strangers: the house is the speaker in each.
        --
        -- Pinned because every part of it fails silently. An `outro` naming a scene that does not exist
        -- plays nothing; a greeting that never mentions the job reads as a shop you wandered into.
        local Conversation = require("models.conversation")
        local Vendor = require("models.vendor")

        local function speaks(def, who)
            for _, node in ipairs((def and def.script) or {}) do
                if node[1] == who then return true end
            end
            return false
        end

        for vendorId in pairs(Vendor.defs) do
            if Vendor.defs[vendorId].class then
                local opener = Errand.opener(vendorId)
                assert(opener, vendorId .. " has no opener at all")

                -- The thanks, wired onto the quest and actually authored.
                local outroId = Quest.defs[opener].outro
                assert(outroId, opener .. " opens a door and says nothing when it is finished")
                local outro = Conversation.defs[outroId]
                assert(outro, opener .. " names an outro that does not exist: " .. tostring(outroId))
                assert(speaks(outro, vendorId),
                    outroId .. " never lets " .. vendorId .. " speak -- the house does not thank you itself")

                -- ...and the greeting behind the door it opened, in that same voice.
                local introId = "conversation_" .. vendorId .. "_vendor_intro"
                local intro = Conversation.defs[introId]
                assert(intro, vendorId .. " opens a shop with no first-visit greeting")
                assert(intro.script and intro.script[1] and intro.script[1][1] == vendorId,
                    introId .. " does not open in the house's own voice")
            end
        end
    end },
}
