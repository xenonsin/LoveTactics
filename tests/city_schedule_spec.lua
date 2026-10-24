-- THE CITY SCHEDULE: one SHELF and one FEATURE per trip home (models/offer.lua's Offer.SCHEDULE).
--
-- What this holds: the trip table itself, the one-and-one cap under any pile-up of events, the player's
-- choice (a root class unlocked) pulling its shelf into the next slot and pushing the scheduled one back,
-- a problem in hand jumping the feature queue, and the ledger keeping a room open once it is admitted.
-- Plus the wiring: every scheduled room is one offer on one desk, and the Armory's tabs follow the city.

local Player = require("models.player")
local Offer = require("models.offer")
local Building = require("models.building")
local Vendor = require("models.vendor")

-- A company with nobody in it, so no body's class pulls a shelf -- the bare schedule.
local function bare()
    local p = Player.new()
    p.roster = {}
    return p
end

-- Put the company at `trip` and let the city catch up. Returns the rooms admitted ON that trip,
-- split by slot.
local function homeOn(p, trip)
    p.tripsCounted = trip
    local rooms = Offer.sync(p)
    local got = { shelves = {}, features = {} }
    for _, slot in ipairs({ "shelves", "features" }) do
        for _, e in ipairs(Offer.SCHEDULE[slot]) do
            if rooms[e.room] == trip then got[slot][#got[slot] + 1] = e.room end
        end
    end
    return got
end

-- Swap a function on a module for the length of `fn`, restoring it whatever happens.
local function with(module, name, stub, fn)
    local was = module[name]
    module[name] = stub
    local ok, err = pcall(fn)
    module[name] = was
    assert(ok, err)
end

-- A body that has UNLOCKED `class`: declared into it and marked on the per-body ledger, so it reads as
-- unlocked whichever reader models/offer.lua is using (Class.canUse, or the fallback).
local function unlockedBody(class)
    local char = require("models.character").instantiate("character_avatar")
    char.declaredClass = class
    char.unlocked = { [class] = true }
    return char
end

local function hexedSword()
    local sword = require("models.item").instantiate("weapon_iron_sword")
    assert(require("models.curse").afflict(sword, "curse_dead_weight"), "the sword takes a hex")
    return sword
end

return {
    {
        name = "the trip table: one shelf and one feature a homecoming, the whole city by trip 8",
        fn = function()
            local expected = {
                [0] = { "bastion.shelf",       "cathedral.mend" },
                [1] = { "cathedral.shelf",     "alchemist.read" },
                [2] = { "arcanum.shelf",       "undercroft.counter" },
                [3] = { "alchemist.shelf",     "hunters_lodge.hire" },
                [4] = { "hunters_lodge.shelf", "bastion.forge" },
                [5] = { "undercroft.shelf",    "hunters_lodge.supper" },
                [6] = { "colosseum.shelf",     "arcanum.bestiary" },
                [7] = { nil,                   "colosseum.duel" },
                [8] = { nil,                   "arcanum.study" },
            }
            local p = bare()
            p.injured = true -- Act 0 carries Rowan up broken; the mending is the first morning's room
            for trip = 0, 8 do
                local got = homeOn(p, trip)
                local want = expected[trip]
                assert(#got.shelves == (want[1] and 1 or 0) and got.shelves[1] == want[1],
                    "trip " .. trip .. " opened shelf " .. tostring(got.shelves[1]) .. ", expected " .. tostring(want[1]))
                assert(#got.features == 1 and got.features[1] == want[2],
                    "trip " .. trip .. " opened feature " .. tostring(got.features[1]) .. ", expected " .. want[2])
            end
            -- Everything with a trip is open by the seventh; only the rite waits on its own event.
            local rooms = Offer.sync(p)
            for _, slot in ipairs({ "shelves", "features" }) do
                for _, e in ipairs(Offer.SCHEDULE[slot]) do
                    if e.trip then assert(rooms[e.room], e.room .. " is still shut on trip 8") end
                end
            end
            assert(not rooms["cathedral.lift"], "the rite opened with nothing hexed")
        end,
    },
    {
        name = "a fresh save opens the Armory, the stair, the knight's house and nothing to mend",
        fn = function()
            local fresh = Player.new()
            local open = {}
            for _, b in ipairs(Building.list(fresh)) do
                if not b.locked then open[#open + 1] = b.id end
            end
            table.sort(open)
            assert(table.concat(open, ",") == "armory,bastion,the_gate",
                "trip 0 with nobody hurt is the two ways out plus the knight's shelf; got " .. table.concat(open, ","))
            assert(not Offer.openSet(fresh, Building.defs.cathedral).mend, "nobody is hurt, so nothing to mend")
            assert(not Offer.openSet(fresh, Building.defs.cathedral).shelf, "the priest's shelf is trip 1's")
        end,
    },
    {
        name = "never more than one shelf and one feature on a trip, however much piles up",
        fn = function()
            local p = bare()
            p.injured = true
            p.stash[#p.stash + 1] = hexedSword()
            p.roster = { unlockedBody("rogue"), unlockedBody("mage"), unlockedBody("hunter") }
            Player.markVendorVisited(p, require("models.identify").VENDOR) -- reads as a find in hand
            with(Player, "brokenKit", function() return { {} } end, function()
                for trip = 0, 9 do
                    local got = homeOn(p, trip)
                    assert(#got.shelves <= 1, "trip " .. trip .. " opened " .. #got.shelves .. " shelves")
                    assert(#got.features <= 1, "trip " .. trip .. " opened " .. #got.features .. " features")
                end
            end)
        end,
    },
    {
        name = "a root unlocked pulls its shelf into the next slot, and the scheduled one waits a trip",
        fn = function()
            local p = bare()
            assert(homeOn(p, 0).shelves[1] == "bastion.shelf", "trip 0 is the knight's shelf")
            -- In town on trip 0, a body unlocks Rogue. The slot for trip 0 is already spent.
            p.roster = { unlockedBody("rogue") }
            assert(not Offer.admitted(p, "undercroft.shelf"), "the pull waits for the next homecoming")
            assert(homeOn(p, 1).shelves[1] == "undercroft.shelf", "trip 1 brings the rogue shelf forward")
            assert(homeOn(p, 2).shelves[1] == "cathedral.shelf", "...and the priest's shelf it displaced is next")
            assert(homeOn(p, 3).shelves[1] == "arcanum.shelf", "the rest of the schedule follows a trip behind")
            -- An ADVANCED class takes no slot: its rows sit on its root's shelf (Vendor.shelves).
            local Class = require("models.class")
            local thief = Class.defs.thief and "thief"
            if thief then
                assert(Vendor.shelves(Vendor.defs.undercroft, thief), "a thief's gear is on the rogue shelf")
                for _, e in ipairs(Offer.SCHEDULE.shelves) do
                    assert(e.class ~= thief, "an advanced class must not hold a slot of its own")
                end
            end
        end,
    },
    {
        name = "a problem in hand takes the feature slot ahead of the schedule, in its order",
        fn = function()
            local p = bare()
            homeOn(p, 0)
            homeOn(p, 1) -- the reading, on the schedule
            p.stash[#p.stash + 1] = hexedSword()
            assert(homeOn(p, 2).features[1] == "cathedral.lift", "a hex in hand jumps the market counter")
            assert(homeOn(p, 3).features[1] == "undercroft.counter", "...which is the next room after it")

            -- Two problems at once: the rite before the forge, one per homecoming.
            local q = bare()
            q.stash[#q.stash + 1] = hexedSword()
            with(Player, "brokenKit", function() return { {} } end, function()
                assert(homeOn(q, 0).features[1] == "cathedral.lift", "the hex is the first problem")
                assert(homeOn(q, 1).features[1] == "bastion.forge", "broken gear outranks the scheduled reading")
                assert(homeOn(q, 2).features[1] == "alchemist.read", "and the reading follows")
            end)

            -- The duel's posting is an event too, ahead of the schedule but behind any problem.
            local r = bare()
            r.completedQuests = { quest_colosseum_slot_01 = true }
            assert(homeOn(r, 0).features[1] == "colosseum.duel", "the posting opens the duel on its own")
        end,
    },
    {
        name = "a room once admitted stays open, and a trip behind the company is never refilled",
        fn = function()
            local p = bare()
            local sword = hexedSword()
            p.stash[#p.stash + 1] = sword
            homeOn(p, 0)
            assert(Offer.admitted(p, "cathedral.lift"), "the rite opened on the hex")
            require("models.curse").lift(sword)
            assert(Offer.openSet(p, Building.defs.cathedral).lift, "lifting the hex must not shut the room")

            -- An injury arriving after the trip's feature slot is spent waits for the next homecoming,
            -- and never back-fills an earlier trip whose slot happened to go unused.
            local q = bare()
            homeOn(q, 0)                                   -- nobody hurt: trip 0's feature slot stays empty
            assert(homeOn(q, 1).features[1] == "alchemist.read")
            q.injured = true
            assert(Offer.openedOn(q, "cathedral.mend") == nil, "trip 1's slot is spent; the mending waits")
            assert(homeOn(q, 2).features[1] == "cathedral.mend", "and opens on the next homecoming")
            assert(Offer.openedOn(q, "cathedral.mend") == 2, "not back-dated onto the empty trip 0")

            -- Mid-visit, with the current trip's slot still free, a problem is admitted on the spot.
            local r = bare()
            for trip = 0, 9 do homeOn(r, trip) end         -- every scheduled feature open, trip 9's slot free
            r.stash[#r.stash + 1] = hexedSword()
            assert(Offer.admitted(r, "cathedral.lift"), "a free slot takes a hex the moment it arrives")
        end,
    },
    {
        name = "nothing is admitted while a run is seated",
        fn = function()
            local p = bare()
            homeOn(p, 0)
            p.descentRun = {}
            p.tripsCounted = 1
            assert(not Offer.admitted(p, "cathedral.shelf"), "a homecoming's rooms wait for the homecoming")
            assert(Offer.admitted(p, "bastion.shelf"), "...and what was open stays open underground")
            p.descentRun = nil
            assert(Offer.admitted(p, "cathedral.shelf"), "home again, the trip's shelf opens")
        end,
    },
    {
        name = "the ledger is plain data the save encoder can carry",
        fn = function()
            local p = bare()
            p.injured = true
            homeOn(p, 3)
            local Save = require("models.save")
            local back = assert(Save.decode("return " .. Save.encode(p.opened, 0)))
            for room, trip in pairs(p.opened.rooms) do
                assert(back.rooms[room] == trip, room .. " did not survive the encoder")
            end
            assert(back.through == p.opened.through, "the closed-through trip did not survive the encoder")
        end,
    },
    {
        name = "every scheduled room is one offer on one desk, and every city gate is scheduled",
        fn = function()
            local scheduled = {}
            for _, slot in ipairs({ "shelves", "features" }) do
                for _, e in ipairs(Offer.SCHEDULE[slot]) do
                    assert(not scheduled[e.room], e.room .. " is scheduled twice")
                    scheduled[e.room] = 0
                end
            end
            for id, def in pairs(Building.defs) do
                for _, offer in ipairs(def.offers or {}) do
                    local room = offer.gate and offer.gate.city
                    if room then
                        assert(room == id .. "." .. offer.answer,
                            id .. "'s " .. tostring(offer.answer) .. " names city room " .. room)
                        assert(scheduled[room], room .. " is gated on the schedule but not on it")
                        scheduled[room] = scheduled[room] + 1
                        assert(not offer.quiet, room .. " is quiet; a scheduled room announces its house")
                    end
                end
            end
            for room, n in pairs(scheduled) do
                assert(n == 1, room .. " is on " .. n .. " desks")
            end
            -- A shelf's class is the class its house's vendor shelves.
            for _, e in ipairs(Offer.SCHEDULE.shelves) do
                local house = e.room:match("^(.-)%.")
                local vdef = Vendor.defs[Building.defs[house].vendor]
                assert(vdef and vdef.class == e.class, e.room .. " pulls on " .. e.class .. ", its vendor shelves "
                    .. tostring(vdef and vdef.class))
            end
            -- The hiring board opens on the third trip home (2026-10-23), Crown or no Crown; the roster
            -- cap is what waits on the Demon Lord (tests/hire_spec.lua).
            local early = bare()
            early.tripsCounted = 2
            assert(not Offer.openSet(early, Building.defs.hunters_lodge).hire, "the hiring board opened before trip 3")
            early.tripsCounted = 3
            assert(Offer.openSet(early, Building.defs.hunters_lodge).hire, "the hiring board is shut on trip 3")
        end,
    },
    {
        name = "the Armory grows with the city: Loadout alone on trip 0, Tactics from trip 1, Classes at Novice 1",
        fn = function()
            local Party = require("ui.panels.party")
            local Class = require("models.class")
            local p = Player.new()
            p.tripsCounted = 0
            assert(not Party.tabOpen(p, "tactics"), "no Tactics tab on the first morning")
            p.tripsCounted = 1
            assert(Party.tabOpen(p, "tactics"), "the Tactics tab arrives with the first trip home")

            if Class.defs.novice then
                local body = require("models.character").instantiate("character_avatar")
                body.declaredClass = "novice"
                p.roster = { body }
                assert(not Party.tabOpen(p, "classes"), "no Classes tab before Novice 1")
                require("models.character").recordTechnique(body, "novice", Class.classLevelCost(1))
                assert(Party.tabOpen(p, "classes"), "Novice 1 opens the Classes tab")
            else
                assert(Party.tabOpen(p, "classes"), "without a Novice class the tab is not held back")
            end
        end,
    },
}
