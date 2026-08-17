-- Tests for models/errand.lua -- the small work a house asks for, and the second gate on its shelf.
--
-- A house opens its DOOR when its circle falls (tests/hub_spec.lua pins that). What it does not do is
-- hand over its catalogue for having beaten a general: the shelf still climbs a rung at a time, and each
-- rung is bought by running an errand. So stock is gated twice -- by the floor reached, and by the work
-- done -- and this file is the second of those.
--
-- The errands ARE the campaign's parked quests, re-seated (see the module header), so most of what is
-- checked here is that the re-reading is faithful: the ordering is the slot order, the ledger is the one
-- the shelf already reads, and a finished errand opens stock through the machinery that existed.

local Errand = require("models.errand")
local Player = require("models.player")
local Quest = require("models.quest")
local Save = require("models.save")
local Vendor = require("models.vendor")

-- A company that has beaten `circles` of this house's circle and is `deepest` floors down.
local function company(vendorId, circles, deepest)
    local p = Player.new()
    p.completedQuests = {}
    p.standing = { [vendorId] = circles or 0 }
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

    { name = "three gates: the circle, the line, and how deep you have been", fn = function()
        local v = "bastion"

        -- The circle first. A house whose door is shut asks for nothing, however deep the company has
        -- gone -- there is nobody to ask.
        local shut = company(v, 0, 40)
        assert(Errand.offered(shut, v, 40) == nil, "a house with its circle unbeaten asks for nothing")

        -- ...and once it is open, the FLOOR still gates it. A company that has beaten the circle but only
        -- gone a floor deep is not being handed the second rung.
        local shallow = company(v, 1, 0)
        assert(Errand.offered(shallow, v, 0) == nil, "a house asks nothing of a company that has not gone down")

        local deep = company(v, 1, Errand.FLOORS_PER_RUNG)
        local first = Errand.offered(deep, v, Errand.FLOORS_PER_RUNG)
        assert(first, "a beaten circle and enough depth should produce an errand")
        assert(first == Errand.forVendor(v)[1], "and it is the first of the line")

        -- The line runs out. A house that has been run dry asks for nothing rather than looping.
        local finished = company(v, 1, 99)
        for _, id in ipairs(Errand.forVendor(v)) do finished.completedQuests[id] = true end
        assert(Errand.offered(finished, v, 99) == nil, "a finished line asks for nothing")
    end },

    { name = "each rung asks the company to have gone deeper than the last", fn = function()
        local v = "bastion"
        local p = company(v, 1, 99)
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
        local p = company(v, 1, 10)
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
        local p = company(v, 1, 99)
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
        local p = company(v, 1, 10)
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
}
