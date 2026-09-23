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
local Injury = require("models.injury")
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

-- The same house as the CARD a screen would hand to Counter.open, rather than its raw blueprint. The
-- difference matters exactly once and it is load-bearing: a blueprint carries no `id` (models/registry
-- keys the table, it does not stamp the def), and Counter.open keys the one-time intro flag off
-- `building.id`. A spec passing the raw def would test a door whose intro flag is "intro_nil".
local function cardFor(player, id)
    for _, card in ipairs(Building.list(player)) do
        if card.id == id then return card end
    end
    error(id .. " is not a card in the city")
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
        -- the Crucible stood on the plaza on the first morning offering a room for an injury nobody had.
        name = "a boolean gate is shut when its condition does not hold",
        fn = function()
            local _, cathedral = houseHolding("mend")
            assert(cathedral, "no house holds the mending")

            local fresh = Player.new()
            assert(not Offer.openSet(fresh, cathedral).mend,
                "nobody has been carried up broken, so there is nothing to mend")

            local hurt = Player.new()
            Injury.inflict(hurt, { { id = "character_rowan" } })
            assert(Offer.openSet(hurt, cathedral).mend, "an injury opens the mending")

            -- One-way: the mark outlives the mending, so the room stays on the desk.
            Injury.mend(hurt, 9)
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
            -- trips alone holds, injury does not, so the pair must not.
            p.runsStarted = 4
            assert(Offer.open(p, { trips = 1 }), "four trips is past one")
            assert(not Offer.open(p, { trips = 1, injury = true }),
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
            local gate = { any = { { injury = true }, { trips = 5 } } }

            local nobody = Player.new()
            assert(not Offer.open(nobody, gate), "neither arm holds, so the room is shut")

            local hurt = Player.new()
            Injury.inflict(hurt, { { id = "character_rowan" } })
            assert(Offer.open(hurt, gate), "the event arm alone opens it")

            local patient = Player.new()
            patient.runsStarted = 5
            assert(Offer.open(patient, gate), "the backstop alone opens it")

            -- It still ANDs with its siblings: `any` is one key among however many.
            assert(not Offer.open(patient, { any = { { injury = true } }, trips = 99 }),
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
        -- A QUIET ROOM DOES NOT ANNOUNCE ITS HOUSE. Every shelf is quiet, and it is the only thing
        -- holding the seven shopfronts off the first morning now that the shelves are ungated: browsing
        -- is not a deed, and a plate arriving for one is the city reacting to nothing the player did.
        --
        -- ...UNLESS THE COMPANY IS TRAINING FOR IT (`announce = { declared = true }`), which is the one
        -- exception and is why this case cannot use the Bastion any more: the starting company is a
        -- knight, so the Bastion's card is now on the plaza on the first morning and is SUPPOSED to be
        -- (tests/class_house_spec.lua holds that half). The Colosseum is the house nobody starts in.
        name = "a quiet room opens without putting its card on the plaza",
        fn = function()
            local quiet = 0
            for id, def in pairs(Building.defs) do
                for _, offer in ipairs(def.offers or {}) do
                    if offer.answer == "shelf" then
                        assert(offer.quiet, id .. "'s shelf must be quiet, or every house opens at once")
                        quiet = quiet + 1
                    end
                end
            end
            assert(quiet == 7, "all seven shelves are quiet, got " .. quiet)

            -- A fresh company: the Colosseum's SHELF is behind its door and nothing is on the board.
            local p = Player.new()
            p.roster = { Character.instantiate("character_rowan") }
            assert(Offer.openSet(p, Building.defs.colosseum).shelf, "the shelf is the house, and is open")
            assert(not Offer.any(p, Building.defs.colosseum), "...and leaves the card off the plaza")
            for _, b in ipairs(Building.list(p)) do
                if b.id == "colosseum" then assert(b.locked, "the Colosseum is still shut") end
            end
        end,
    },
    {
        -- A DOOR AND ITS ROOMS ARE TWO QUESTIONS, and the Cathedral is where they part: the card has to
        -- arrive on an injury -- a deed -- while the mending behind it is the room that deed opened, and
        -- the shelf beside it has never been gated on anything at all.
        --
        -- THE SHELF USED TO BE THE THIRD ANSWER HERE, shut until somebody held a priest level. That is
        -- the case this file asserted for the whole of the fold and it was the bug: a card on the plaza,
        -- a keeper at the desk, and no shop. A shelf is the house.
        name = "a door opens on any room behind it, and the shop is always one of them",
        fn = function()
            local function locked(who, id)
                for _, b in ipairs(Building.list(who)) do
                    if b.id == id then return b.locked end
                end
                error(id .. " is not a card in the city")
            end
            local cathedralId, cathedral = houseHolding("mend")

            local hurt = Player.new()
            Injury.inflict(hurt, { { id = "character_rowan" } })
            assert(not locked(hurt, cathedralId), "an injury stands the door open")
            assert(Offer.openSet(hurt, cathedral).shelf, "...and the shop is behind it, as it always is")

            -- ...and NOT the other way round, which is the half the quiet flag buys. Nobody hurt: the
            -- shelf is open behind a card that is not on the board, and there is nothing to mend.
            local well = Player.new()
            well.roster = { Character.instantiate("character_rowan") }
            assert(Offer.openSet(well, cathedral).shelf, "the shop is open for anyone who reaches it")
            assert(locked(well, cathedralId), "...and leaves the door shut, because a shelf is quiet")
            assert(not Offer.openSet(well, cathedral).mend, "and there is still nothing to mend")
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
            Injury.inflict(hurt, { { id = "character_rowan" } })

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
    {
        -- THE DESK IS WHAT THE PLAYER CAME THROUGH THE DOOR FOR, so on an ordinary visit it is the first
        -- thing they see. A counter scene opens on a line of the keeper's flavour, and that line is a
        -- greeting -- fine on the visit the house is introducing itself, a keypress in the way on the
        -- two hundred visits after it. Counter.open hands `startAt` the desk's own id whenever
        -- VendorVisit had nothing to play.
        --
        -- STUBBED AT Conversation.play, because the sequencing is the whole feature and it is the one
        -- part of this model that cannot be reached without a window. The stub answers LEAVE so the
        -- pass walks straight back out; what it records is the id and the `startAt` of every scene.
        name = "a house with nothing new to say opens ON the desk, not on the keeper's preamble",
        fn = function()
            local Conversation = require("models.conversation")
            local Vendor = require("models.vendor")
            local VendorVisit = require("models.vendor_visit")
            local cathedralId = houseHolding("mend")

            -- A company that has been here: the room's one-time scene spent, the greeting heard, every
            -- discipline this shelf stocks already announced.
            local known = Player.new()
            known.flags = known.flags or {}
            known.flags["intro_" .. cathedralId] = true
            local cathedral = cardFor(known, cathedralId)
            Player.markVendorVisited(known, cathedral.vendor)
            local class = Vendor.get(cathedral.vendor).class
            for _, classId in ipairs(Class.pendingAnnouncements(known, class)) do
                Player.markDisciplineAnnounced(known, classId)
            end
            assert(#VendorVisit.steps(known, cathedral.vendor, 0) == 0,
                "this house has nothing left to say, which is the case under test")

            local played = {}
            local real = Conversation.play
            Conversation.play = function(id, onDone, ctx, opts)
                played[#played + 1] = { id = id, startAt = opts and opts.startAt }
                onDone(Counter.LEAVE)
            end
            local ok, err = pcall(Counter.open, known, cathedral, function() end, nil)
            Conversation.play = real
            assert(ok, tostring(err))

            assert(#played == 1, "one scene plays behind the door, the counter's own; got " .. #played)
            assert(played[1].id == cathedral.counter, "...and it is this house's counter scene")
            assert(played[1].startAt == Counter.DESK,
                "the scene opened at its top, so the player reads flavour before the desk again")

            -- THE DESK MUST SURVIVE RESOLUTION or `startAt` falls back to the top of the script without
            -- saying so (ui/dialogue.lua), which is this feature silently doing nothing. That is why the
            -- desk node carries no `when` -- asserted here for every house rather than only written down.
            for id, def in pairs(Building.defs) do
                if def.counter then
                    local resolved = Conversation.resolve(Conversation.defs[def.counter],
                        Counter.context(known, def))
                    local at = Conversation.nextIndex(resolved.script, 0, Counter.DESK)
                    assert(at, id .. "'s desk does not survive resolution, so its counter opens on the top")
                end
            end
        end,
    },
    {
        -- The other half of the same switch: a house that HAS something to say still says it, and its
        -- counter scene then plays whole -- the preamble rides the visit the greeting is on.
        name = "a house with something to say speaks first, and its scene plays from the top",
        fn = function()
            local Conversation = require("models.conversation")
            local cathedralId = houseHolding("mend")

            local stranger = Player.new()
            stranger.flags = stranger.flags or {}
            stranger.flags["intro_" .. cathedralId] = true -- the room's own scene is not what is tested
            local cathedral = cardFor(stranger, cathedralId)

            local played = {}
            local real = Conversation.play
            Conversation.play = function(id, onDone, ctx, opts)
                played[#played + 1] = { id = id, startAt = opts and opts.startAt }
                onDone(Counter.LEAVE)
            end
            local ok, err = pcall(Counter.open, stranger, cathedral, function() end, nil)
            Conversation.play = real
            assert(ok, tostring(err))

            assert(#played >= 2, "the greeting plays and then the counter; got " .. #played .. " scene(s)")
            assert(played[1].id == "conversation_" .. cathedral.vendor .. "_vendor_intro",
                "the house greets a stranger first, got " .. tostring(played[1].id))
            local last = played[#played]
            assert(last.id == cathedral.counter, "...and the counter scene follows it")
            assert(last.startAt == nil, "which plays whole, preamble included, on the visit it is earned")
        end,
    },
    {
        -- A SCENE THAT WAITS FOR A DEED INSTEAD OF A DOOR (`introAfter`). The Cathedral is the only
        -- house that carries one and it is the reason the field exists: its scene hands over Xin, and
        -- played in the doorway it introduced the healer one beat BEFORE she was any use -- she said a
        -- bone could be set, then stood there while the player set it off a menu. It plays on the way
        -- out of the mending now, so she is the hands on the press.
        --
        -- THREE THINGS, and the order is the feature: nothing but the desk at the door, the room, then
        -- the scene. The greeting stays deferred exactly as it was when the scene played at the door --
        -- one scene per trip through, and on this trip it is hers.
        name = "a house whose scene waits for a deed plays it on the way OUT of that room",
        fn = function()
            local Conversation = require("models.conversation")
            local cathedralId, def = houseHolding("mend")
            assert(def.introAfter == "mend",
                "the Cathedral's scene no longer waits for the mending -- retarget this case")
            assert(def.intro and def.grants, "...and it is still the scene that hands over its companion")

            local player = Player.new()
            Injury.inflict(player, { { id = "character_rowan" } })
            local cathedral = cardFor(player, cathedralId)

            -- The desk answers `mend` once and then walks out, and every room hands straight back --
            -- which is what the coached morning's rail does for real (ui/panels/ward.lua).
            local played, opened, answers = {}, {}, { "mend" }
            local real = Conversation.play
            Conversation.play = function(id, onDone, _, _)
                played[#played + 1] = id
                if id == cathedral.counter then return onDone(table.remove(answers, 1) or Counter.LEAVE) end
                onDone()
            end
            local ok, err = pcall(Counter.open, player, cathedral, function(room, onClosed)
                opened[#opened + 1] = room.panel
                onClosed()
            end, nil)
            Conversation.play = real
            assert(ok, tostring(err))

            assert(played[1] == cathedral.counter,
                "the door opens on the desk, got " .. tostring(played[1]))
            assert(opened[1] == "ward", "the mending is what opened, got " .. tostring(opened[1]))
            assert(played[2] == def.intro,
                "the house's scene plays as the room shuts, got " .. tostring(played[2]))
            for _, id in ipairs(played) do
                assert(id ~= "conversation_" .. cathedral.vendor .. "_vendor_intro",
                    "the shopkeeper's greeting must stay deferred on the visit the scene fires")
            end

            -- ...and it spends its flag and hands over its companion, exactly as it did at the door.
            assert(player.flags["intro_" .. cathedralId], "the scene is spent once, ever")
            local joined = false
            for _, char in ipairs(player.roster) do
                if char.id == def.grants then joined = true end
            end
            assert(joined, def.grants .. " did not join out of the scene she is granted by")

            -- A SECOND TRIP THROUGH THE SAME ROOM SAYS NOTHING. The flag is the only ledger, so this
            -- is the case that fails the day the scene starts keying off the room instead.
            local again = {}
            answers = { "mend" }
            Conversation.play = function(id, onDone, _, _)
                again[#again + 1] = id
                if id == cathedral.counter then return onDone(table.remove(answers, 1) or Counter.LEAVE) end
                onDone()
            end
            local ok2, err2 = pcall(Counter.open, player, cathedral, function(_, onClosed) onClosed() end, nil)
            Conversation.play = real
            assert(ok2, tostring(err2))
            for _, id in ipairs(again) do
                assert(id ~= def.intro, "the house's one-time scene played twice")
            end
        end,
    },
    {
        -- A GATE SAYS THE ROOM IS THERE; THE MARK SAYS IT WANTS YOU TODAY. The Cathedral's mending
        -- stands on the desk forever once anybody has been carried up broken -- that is the gate doing
        -- its job, and the spec above pins it -- so without a second question a desk of four identical
        -- lines makes the player open all four to find out which one has anything in it.
        --
        -- AND THE MARK MUST BE ABLE TO GO OUT, which is the half that decides whether any of this is
        -- worth drawing. `unattended` rather than `injured`: a body already lying up is being dealt
        -- with, and a room that went on flagging it would be asking for a decision already made.
        name = "a room is marked while it has something in it, and the mark goes out when it is dealt with",
        fn = function()
            local _, cathedral = houseHolding("mend")
            assert(cathedral, "no house holds the mending")

            local well = Player.new()
            assert(not Offer.newsSet(well, cathedral).mend,
                "nobody is hurt, so the mending has nothing waiting in it")

            local hurt = Player.new()
            Injury.inflict(hurt, { { id = "character_rowan" } })
            assert(Offer.newsSet(hurt, cathedral).mend, "a body nobody has seen to marks the room")

            -- Lying up is an ANSWER to an injury, not an injury ignored: the stay is served by descending
            -- (models/injury.lua), so the room stops asking the moment the player has decided.
            Injury.rest(hurt, "character_rowan")
            assert(not Offer.newsSet(hurt, cathedral).mend,
                "a body already resting is being dealt with -- a mark that cannot go out is noise")
        end,
    },
    {
        -- THE RITE IS THE MENDING'S TWIN WITH AN ITEM WHERE THE BODY GOES, and it wears the same mark
        -- on the same terms -- a hex is a thing the company is still CARRYING, so it clears when the
        -- curse is lifted rather than when the line is looked at.
        name = "a hex marks the rite, and lifting it puts the mark out",
        fn = function()
            local Item = require("models.item")
            local Curse = require("models.curse")
            local _, cathedral = houseHolding("lift")
            assert(cathedral, "no house holds the rite")

            local p = Player.new()
            assert(not Offer.newsSet(p, cathedral).lift, "nothing is hexed on a fresh save")

            local sword = Item.instantiate("weapon_iron_sword")
            p.stash[#p.stash + 1] = sword
            assert(Curse.afflict(sword, "curse_cold_iron"), "the sword takes Cold Iron")
            assert(Offer.newsSet(p, cathedral).lift, "a hexed piece marks the rite")

            Curse.lift(sword)
            assert(not Offer.newsSet(p, cathedral).lift, "and lifting it takes the mark off")
        end,
    },
    {
        -- A MARK IS ONLY EVER PUT ON SOMETHING THE PLAYER CAN WALK IN AND SEE. The rule is older than
        -- this file -- it cost the Market its dot once and all seven houses theirs a second time -- and
        -- the shape of the failure is always the same: a mark raised on a looser question than the
        -- screen behind it clears on, so the player opens the door, reads everything, walks out, and the
        -- plate is still burning. A room the desk will not print is the purest case of that.
        name = "a shut room never carries a mark, and no house marks a line it would not print",
        fn = function()
            local hurt = Player.new()
            Injury.inflict(hurt, { { id = "character_rowan" } })

            assert(Offer.news(hurt, { answer = "mend", panel = "ward", open = true }),
                "the ward has a body waiting in it")
            assert(not Offer.news(hurt, { answer = "mend", panel = "ward", open = false }),
                "...and a room that is not on the desk yet must not be marked for it")

            -- The sweep: whatever any house is marking, its desk is printing.
            for id, def in pairs(Building.defs) do
                local open, news = Offer.openSet(hurt, def), Offer.newsSet(hurt, def)
                for answer in pairs(news) do
                    assert(open[answer], id .. " marks '" .. answer .. "', which its desk will not offer")
                end
            end
        end,
    },
    {
        -- THE DOOR AND THE DESK ASK ONE QUESTION. The plate out on the plaza is the OR over the rooms
        -- behind it and a desk line is one entry of the same call, so a city that says "there is
        -- something in this house" always opens on a line saying which room it is in.
        name = "a house's plate is the OR over the marks on its own desk",
        fn = function()
            local hurt = Player.new()
            Injury.inflict(hurt, { { id = "character_rowan" } })

            local marked = 0
            for id, def in pairs(Building.defs) do
                local any = false
                for _ in pairs(Offer.newsSet(hurt, def)) do any = true; break end
                assert(Offer.anyNews(hurt, def) == any,
                    id .. "'s plate and its desk disagree about whether anything is waiting")
                if any then marked = marked + 1 end
            end
            assert(marked == 1, "one injury lights exactly the house that mends it, got " .. marked)
        end,
    },
    {
        -- ...AND THE MARK REACHES THE LINE. Everything above is about the model; this is the wiring,
        -- which is the half that can ship green and draw nothing. A counter hands its news set over on
        -- the conversation context, the resolver stamps the option it belongs to, and ui/dialogue.lua
        -- draws the same red dot the plate outside wears (ui/glyphs.lua's unseenDot).
        --
        -- Rebuilt on every pass through the desk, which is why the mark can go out WITHOUT closing the
        -- door: see to the bone, come back from the room, and the line the player just used is plain.
        name = "the desk's own option carries the mark, and only that option",
        fn = function()
            local Conversation = require("models.conversation")
            local id, cathedral = houseHolding("mend")
            local hurt = Player.new()
            Injury.inflict(hurt, { { id = "character_rowan" } })

            local scene = Conversation.resolve(Conversation.defs[cathedral.counter],
                Counter.context(hurt, cathedral))
            local desk
            for _, node in ipairs(scene.script) do
                if node.id == Counter.DESK then desk = node end
            end
            assert(desk and desk.choices, id .. "'s scene ends on a desk of rooms")

            local marked, leave = nil, nil
            for _, choice in ipairs(desk.choices) do
                if choice.news then marked = choice.answer end
                if choice.answer == Counter.LEAVE then leave = choice end
            end
            assert(marked == "mend", "the mending line wears the dot, got " .. tostring(marked))
            assert(leave and not leave.news, "and the way out never does")

            -- Seen to, asked again: the same desk, no dot.
            Injury.rest(hurt, "character_rowan")
            local after = Conversation.resolve(Conversation.defs[cathedral.counter],
                Counter.context(hurt, cathedral))
            for _, node in ipairs(after.script) do
                if node.id == Counter.DESK then
                    for _, choice in ipairs(node.choices or {}) do
                        assert(not choice.news, "'" .. tostring(choice.answer)
                            .. "' still wears a dot after the injury was answered")
                    end
                end
            end
        end,
    },
}
