-- THE COUNTERS: a house's desk, the rooms behind it, and what opens each one.
--
-- models/offer.lua answers one question -- is this room open -- for two readers that must never
-- disagree: the DOOR out on the plaza (models/building.lua draws a card when any room behind it is
-- open) and the DESK LINE inside it (the `offer` predicate in a counter scene's `when`). A desk that
-- could disagree with its own card would offer a room the player cannot reach, or hide one they can.
--
-- models/counter.lua is the sequencer over that, and is deliberately UI-free -- it plays scenes and
-- hands a room back to whatever state owns the screen -- so everything but the scene playback is
-- exercisable here, headless.

local Building = require("models.building")
local Counter = require("models.counter")
local Offer = require("models.offer")
local Player = require("models.player")
local Character = require("models.character")
local Class = require("models.class")
local Wound = require("models.wound")
local Descent = require("models.descent")

-- A house, found by the room it holds rather than named, so moving a room to another house is a
-- blueprint edit and not a spec edit.
local function houseHolding(answer)
    for id, def in pairs(Building.defs) do
        for _, offer in ipairs(def.offers or {}) do
            if offer.answer == answer then return id, def end
        end
    end
end

return {
    {
        name = "every offer names a panel that exists, and every house's desk scene is authored",
        fn = function()
            local counters = 0
            for id, def in pairs(Building.defs) do
                if def.counter then counters = counters + 1 end
                for _, offer in ipairs(def.offers or {}) do
                    assert(offer.answer, id .. " has an offer with no answer to name it")
                    assert(offer.panel, id .. "'s '" .. offer.answer .. "' opens no panel")
                    local ok = pcall(require, "ui.panels." .. offer.panel)
                    assert(ok, id .. "'s '" .. offer.answer .. "' names panel '" .. offer.panel
                        .. "', which does not load")
                    -- A room's own vendor is optional, but a named one must be real -- a typo here is a
                    -- shelf that silently falls back to the house's own.
                    if offer.vendor then
                        assert(require("models.vendor").defs[offer.vendor],
                            id .. "'s '" .. offer.answer .. "' names vendor '" .. offer.vendor .. "'")
                    end
                end
            end
            assert(counters == 7, "seven houses keep a desk, got " .. counters)
        end,
    },
    {
        -- THE BUG THIS PINS SHIPPED, briefly: `want and is or not is` is the obvious way to write a
        -- boolean gate and it is wrong in Lua whenever `is` is false -- it falls through to the `or`
        -- arm and answers TRUE. Both boolean gates read as OPEN on a fresh save, and the Cathedral and
        -- the Crucible stood on the plaza on the first morning offering a room for a wound nobody had.
        name = "a boolean gate is shut when its condition does not hold",
        fn = function()
            local _, cathedral = houseHolding("mend")
            assert(cathedral, "no house holds the mending")

            local fresh = Player.new()
            assert(not Offer.openSet(fresh, cathedral).mend,
                "nobody has been carried up broken, so there is nothing to mend")

            local hurt = Player.new()
            Wound.inflict(hurt, { { id = "character_rowan" } })
            assert(Offer.openSet(hurt, cathedral).mend, "a wound opens the mending")

            -- One-way: the mark outlives the mending, so the room stays on the desk.
            Wound.mend(hurt, 9)
            assert(Offer.openSet(hurt, cathedral).mend,
                "setting the bone must not take the room away again")
        end,
    },
    {
        name = "a gate ANDs every key, and an unknown key is loud rather than open",
        fn = function()
            local p = Player.new()
            assert(Offer.open(p, nil), "no gate is open")
            assert(Offer.open(p, {}), "an empty gate is open")
            -- trips alone holds, wound does not, so the pair must not.
            p.runsStarted = 4
            assert(Offer.open(p, { trips = 1 }), "four trips is past one")
            assert(not Offer.open(p, { trips = 1, wound = true }),
                "every key in a gate must hold")
            assert(not pcall(Offer.open, p, { notARealGate = true }),
                "an unknown gate key is a blueprint typo and must raise, not read as open")
        end,
    },
    {
        -- THE CITY GROWS ON TRIPS HOME, NOT ON DEPTH, and the two must never be confused again.
        --
        -- `expeditionsOut` is max(bounties, deepest). Measured on the old gates: a company that pushed to
        -- floor four on its FIRST descent came home to four new doors at once and then three empty
        -- homecomings, and a company that farmed floor one had its city frozen after the first. Trips
        -- climb by one and only by coming back, so one room per homecoming falls out of the unit.
        name = "the trip clock climbs one at a time and is not depth",
        fn = function()
            local diver = Player.new()
            Descent.reached(diver, 9)
            diver.runsStarted = 1
            assert(Player.tripsHome(diver) == 1, "nine floors in one dive is still one trip home")
            assert(Player.expeditionsOut(diver) >= 9, "...while the depth record says nine")
            assert(Offer.open(diver, { trips = 1 }), "one trip is one trip")
            assert(not Offer.open(diver, { trips = 2 }), "a deep dive must not buy a second trip")

            local farmer = Player.new()
            Descent.reached(farmer, 1)
            farmer.runsStarted = 5
            assert(Offer.open(farmer, { trips = 5 }),
                "five shallow trips are five trips -- a farmer's city must not freeze")
            assert(not Offer.open(farmer, { expeditions = 2 }),
                "...and depth is still depth, which is what the shelves are priced on")
        end,
    },
    {
        -- AN EVENT THAT MAY NEVER FIRE NEEDS A BACKSTOP. The Crucible's reading is the best gate in the
        -- game -- the card arrives holding exactly the problem it solves -- but whether it fires at all
        -- is up to the drops, and the drops do not know the door exists.
        name = "an `any` gate holds on the event or on the backstop, and needs one of them",
        fn = function()
            local gate = { any = { { wound = true }, { trips = 5 } } }

            local nobody = Player.new()
            assert(not Offer.open(nobody, gate), "neither arm holds, so the room is shut")

            local hurt = Player.new()
            Wound.inflict(hurt, { { id = "character_rowan" } })
            assert(Offer.open(hurt, gate), "the event arm alone opens it")

            local patient = Player.new()
            patient.runsStarted = 5
            assert(Offer.open(patient, gate), "the backstop alone opens it")

            -- It still ANDs with its siblings: `any` is one key among however many.
            assert(not Offer.open(patient, { any = { { wound = true } }, trips = 99 }),
                "a satisfied `any` must not excuse the other keys in the same gate")

            -- And the shipped rooms that use it really do carry both arms, or the backstop is prose.
            local _, crucible = houseHolding("read")
            local read
            for _, offer in ipairs(crucible.offers) do
                if offer.answer == "read" then read = offer end
            end
            assert(read.gate and read.gate.any and #read.gate.any == 2,
                "the reading should keep its event AND a backstop")
        end,
    },
    {
        -- A QUIET ROOM DOES NOT ANNOUNCE ITS HOUSE. Every shelf is quiet: a class rung is a reward the
        -- player cannot see, and hanging a door on it put two shopfronts on the plaza the moment Act 0
        -- ended -- onto rung-1 shelves that stock almost nothing.
        name = "a quiet room opens without putting its card on the plaza",
        fn = function()
            local quiet = 0
            for id, def in pairs(Building.defs) do
                for _, offer in ipairs(def.offers or {}) do
                    if offer.answer == "shelf" then
                        assert(offer.quiet, id .. "'s shelf must be quiet, or a class rung opens a door")
                        quiet = quiet + 1
                    end
                end
            end
            assert(quiet == 7, "all seven shelves are quiet, got " .. quiet)

            -- A body a rung into the knight opens the Bastion's SHELF and nothing on the board.
            local p = Player.new()
            p.roster = { Character.instantiate("character_rowan") }
            Character.recordTechnique(p.roster[1], "knight", Class.classLevelCost(1))
            assert(Offer.openSet(p, Building.defs.bastion).shelf, "the rung stocks the shelf")
            assert(not Offer.any(p, Building.defs.bastion), "...and leaves the card off the plaza")
            for _, b in ipairs(Building.list(p)) do
                if b.id == "bastion" then assert(b.locked, "the Bastion is still shut") end
            end
        end,
    },
    {
        -- A DOOR AND ITS SHELF ARE TWO QUESTIONS. This is the whole reason the fold was possible: the
        -- Cathedral has to be open on the first morning for a wound, while its shelf waits on a priest
        -- level nobody has.
        name = "a door opens on any room behind it, and a shelf on its own class",
        fn = function()
            local function locked(who, id)
                for _, b in ipairs(Building.list(who)) do
                    if b.id == id then return b.locked end
                end
                error(id .. " is not a card in the city")
            end
            local cathedralId, cathedral = houseHolding("mend")

            local hurt = Player.new()
            Wound.inflict(hurt, { { id = "character_rowan" } })
            assert(not locked(hurt, cathedralId), "a wound stands the door open")
            assert(not Offer.openSet(hurt, cathedral).shelf, "...and the shelf stays shut behind it")

            -- ...and NOT the other way round, which is the half the quiet flag buys. A priest rung with
            -- nobody hurt stocks the shelf and leaves the card off the board: the player banked that rung
            -- by fighting, never chose it, and a shopfront appearing for it is the city reacting to
            -- something invisible.
            local priest = Player.new()
            priest.roster = { Character.instantiate("character_rowan") }
            Character.recordTechnique(priest.roster[1], "priest", Class.classLevelCost(1))
            assert(Offer.openSet(priest, cathedral).shelf, "a priest rung stocks the shelf")
            assert(locked(priest, cathedralId), "...and leaves the door shut, because a shelf is quiet")
            assert(not Offer.openSet(priest, cathedral).mend, "and there is still nothing to mend")
        end,
    },
    {
        -- A FOLDED ROOM KEEPS ITS OWN VENDOR, which is not a nicety: `sellsAll` makes a Buy tab the
        -- market's two racks INSTEAD of a class ladder (ui/panels/shop.lua), so pouring the town counter
        -- into the Undercroft's vendor would have deleted the rogue shelf rather than merged with it.
        name = "a room may keep its own counter, and the house's is the default",
        fn = function()
            local id, house = houseHolding("counter")
            assert(house, "no house holds the town counter")

            local p = Player.new()
            p.runsStarted = 1

            local town = Offer.roomFor(p, house, "counter")
            assert(town, "the town counter should be open one floor in")
            assert(town.vendor ~= house.vendor,
                id .. "'s town counter must keep its own vendor, or it overwrites the house's shelf")

            -- Its own shelf falls back to the house's vendor.
            local shelf
            for _, offer in ipairs(Offer.list(p, house)) do
                if offer.answer == "shelf" then shelf = offer end
            end
            assert(shelf and shelf.vendor == house.vendor, "a room with no vendor of its own uses the house's")
        end,
    },
    {
        -- ANYTHING THAT IS NOT AN OPEN ROOM MEANS "WALK OUT". Three cases land here and all three must
        -- open nothing: the Exit line, a typo in a blueprint, and a room whose gate is still shut.
        name = "an answer that is not an open room opens nothing",
        fn = function()
            local _, cathedral = houseHolding("mend")
            local fresh = Player.new()
            assert(Offer.roomFor(fresh, cathedral, Counter.LEAVE) == nil, "the exit opens no room")
            assert(Offer.roomFor(fresh, cathedral, "not_a_room") == nil, "an unknown answer opens no room")
            assert(Offer.roomFor(fresh, cathedral, "mend") == nil,
                "a room whose gate is shut opens nothing, even if the desk somehow offered it")
            assert(Offer.roomFor(fresh, cathedral, nil) == nil, "no answer at all opens no room")
        end,
    },
    {
        -- The context a desk scene is resolved against carries the open rooms, and nothing else does --
        -- so the `offer` predicate never holds in an ordinary conversation.
        name = "a counter's context carries its open rooms, and an ordinary scene's carries none",
        fn = function()
            local _, cathedral = houseHolding("mend")
            local hurt = Player.new()
            Wound.inflict(hurt, { { id = "character_rowan" } })

            local ctx = Counter.context(hurt, cathedral)
            assert(ctx.offers and ctx.offers.mend, "the desk's context knows the mending is open")
            assert(ctx.roster and ctx.quests and ctx.flags, "...and is still an ordinary context")

            local plain = require("models.conversation").context(hurt)
            assert(plain.offers and next(plain.offers) == nil,
                "a scene played outside a counter has no offers, so `offer` never holds")
        end,
    },
    {
        name = "a door with no rooms is not a shut door",
        fn = function()
            -- The Armory and the Rift declare no offers and keep their own gates. A building with an
            -- empty offer list answering "shut" would have deleted both doors on the first morning.
            assert(Offer.any(Player.new(), Building.defs.armory), "the Armory has no rooms and is open")
            assert(Offer.any(Player.new(), Building.defs.the_gate), "the Rift has no rooms and is open")
            assert(not Counter.has(Building.defs.armory), "the Armory keeps no desk")
            assert(not Counter.has(Building.defs.the_gate), "the Rift keeps no desk")
        end,
    },
}
