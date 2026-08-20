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

        local open = company(v, true, 0)
        local reach = Errand.floorFor(open, v)
        local deep = company(v, true, reach)
        local next2 = Errand.offered(deep, v, reach)
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
        -- ...with the OTHER houses' subclass work behind it. Three of the Bastion's six rungs are
        -- multiclass capstones, and each names a subclass job at the other parent (a warden wants the
        -- Lodge, a vanguard the Undercroft) -- so a company that had worked nowhere else would find the
        -- Bastion out of things it could ask for, which is the cross-house chain doing its job rather
        -- than the ladder failing. See Errand.next.
        local Discipline = require("models.discipline")
        for _, def in pairs(Discipline.defs) do
            if #def.classes == 1 then
                for _, q in ipairs(def.requiredQuests or {}) do
                    if (Quest.defs[q] or {}).sponsor ~= v then p.completedQuests[q] = true end
                end
            end
        end
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

    { name = "every errand opens a rung, and the line stops when the shelf does", fn = function()
        -- NO DEAD JOB AT THE END OF A LINE. An errand opens the slot its own count names (the opener
        -- takes 0, each after it the next), so a house asking for more jobs than its shelf has rungs
        -- ends on one that pays no stock -- and under Errand.floorFor that one would sit on the deepest
        -- floor in the game. The surplus is dropped from the line instead.
        local Item = require("models.item")
        for vendorId in pairs(Errand.houses()) do
            local line = Errand.forVendor(vendorId)
            local class = (Vendor.get(vendorId) or {}).class
            -- Measured on the house's OWN stock, not on everything its shelf carries: a multiclass ware
            -- lands on both its parents' shelves and keeps the slot its home house gave it, so the Lodge's
            -- eight-rung stock shows up on the Bastion's six-rung shelf at slot 7 and means nothing there.
            local top, atTop = -1, 0
            for id, def in pairs(Item.defs) do
                if def.price and def.class == class then
                    local slot = def.unlockQuests or 0
                    if slot > top then top, atTop = slot, 0 end
                    if slot == top then atTop = atTop + 1 end
                end
            end
            assert(#line == top + 1, vendorId .. " asks for " .. #line .. " errands over "
                .. (top + 1) .. " rungs of its own stock")
            assert(atTop > 0, vendorId .. " has nothing on its top rung")

            -- ...and the trim takes the tail, which is a house's side work -- unless the tail is a job a
            -- discipline hangs off, in which case the cut moves up the list and a numbered rung goes
            -- instead. Gates outrank the ladder: a lost numbered slot costs one fight, a lost gate costs
            -- a whole discipline. (The Crucible is the standing case -- both its tail jobs are gates.)
            local kept = {}
            for _, id in ipairs(line) do kept[id] = true end
            for id, def in pairs(Quest.defs) do
                if def.sponsor == vendorId and def.map and def.map.objective and not kept[id] then
                    for _, disc in pairs(require("models.discipline").defs) do
                        for _, gate in ipairs(disc.requiredQuests or {}) do
                            assert(gate ~= id, vendorId .. " cut " .. id .. ", which opens a discipline")
                        end
                    end
                end
            end
        end
    end },

    { name = "every discipline's gate quest is still asked for", fn = function()
        -- A DISCIPLINE HANGS OFF ONE NAMED QUEST, and the descent is the only mode there is -- so a
        -- quest that is not an errand is a quest nobody can finish, and the discipline behind it can
        -- never be unlocked by anyone. Nineteen of the thirty-eight gates are `the_*` side jobs, which
        -- is exactly the tail Errand.forVendor trims to fit the shelf's rungs.
        local Discipline = require("models.discipline")
        local asked = {}
        for vendorId in pairs(Errand.houses()) do
            for _, id in ipairs(Errand.forVendor(vendorId)) do asked[id] = true end
        end
        for id, def in pairs(Discipline.defs) do
            for _, questId in ipairs(def.requiredQuests or {}) do
                assert(asked[questId], id .. " gates on " .. questId .. ", which no house asks for")
            end
        end
    end },

    { name = "every house's line fits inside one descent", fn = function()
        -- THE PROMISE: no errand is gated on a floor the mode does not have. It used to be one rung per
        -- two floors, so a fifteen-floor descent could be asked for seven of a line of twelve to
        -- fourteen -- and the rest, with the shelf rungs they open, stood behind floor sixteen.
        local Descent = require("models.descent")
        local deepest = Descent.CIRCLE_FLOORS
        assert(deepest < Descent.FLOORS, "the bottom is the Crown's floor and seats no errand")
        -- AND THE LADDER STOPS SHORT OF IT. The top of a shelf is bought at floor 12, which leaves the
        -- seventh circle and the Crown to spend it in -- a company should not buy the best gear the game
        -- sells and immediately fight the last thing in the game with it.
        assert(Descent.FLOORS - (Errand.LAST_ASK_FLOOR + 1) >= 3,
            "the last rung leaves no room to play with what it opened")

        for vendorId in pairs(Errand.houses()) do
            local line = Errand.forVendor(vendorId)
            local p = company(vendorId, true, 99)
            local last, floors = 0, {}
            for n = 2, #line do -- from the second: the opener is found, never asked for
                -- ...standing on the line with n-1 of its errands run, which is what floorFor reads.
                p.completedQuests = {}
                for i = 1, n - 1 do p.completedQuests[line[i]] = true end
                local floor = Errand.floorFor(p, vendorId)
                assert(floor >= last, vendorId .. " asks for errand " .. n .. " shallower than the one before")
                assert(floor >= 1 and floor <= deepest,
                    vendorId .. " seats errand " .. n .. " on floor " .. floor .. ", which no run reaches")
                last, floors[n] = floor, floor
            end
            -- Every house finishes on the last rung floor, give or take the one-floor stagger that keeps
            -- the five six-rung houses from all asking on the same five floors.
            assert(floors[#line] >= Errand.LAST_ASK_FLOOR and floors[#line] <= Errand.LAST_ASK_FLOOR + 1,
                vendorId .. " does not finish its ladder where every other house does: its last errand "
                    .. "sits on floor " .. tostring(floors[#line]) .. ", not " .. Errand.LAST_ASK_FLOOR)
        end
    end },

    { name = "a finished errand opens the shelf by the path the shelf already read", fn = function()
        -- THE LEDGER IS THE ONE THAT EXISTED. Stock is gated on Quest.shelfRung, which is the count of
        -- completed quests per sponsor less the opener -- so an errand completes by writing
        -- `completedQuests`, and the shop opens with no second tally that could disagree with the first.
        local v = "bastion"
        local p = company(v, true, 99)
        local before = Vendor.stock(v, Quest.shelfRung(p, v))
        local openBefore = 0
        for _, e in ipairs(before) do if not e.locked then openBefore = openBefore + 1 end end

        Errand.complete(p, Errand.next(p, v))
        assert(Quest.sponsorProgress(p, v) >= 1, "the shelf's own counter moved")

        local after = Vendor.stock(v, Quest.shelfRung(p, v))
        local openAfter = 0
        for _, e in ipairs(after) do if not e.locked then openAfter = openAfter + 1 end end
        assert(openAfter > openBefore,
            "running an errand opened nothing: " .. openBefore .. " -> " .. openAfter)
    end },

    { name = "the opener opens the bottom band and only that", fn = function()
        -- THE FIRST ERRAND BUYS SLOT 0. It used to buy slot 0 and slot 1 together: the bottom band is
        -- authored at slot 0, which a standing of nought already cleared, and the opener also moved the
        -- standing to one -- so a freshly opened door had eleven of the Arcanum's wares behind it, eight
        -- of them free. Quest.shelfRung is the offset that separates the door from the first rung.
        for _, v in ipairs({ "bastion", "arcanum" }) do
            local shut = company(v, false, 99)
            for _, e in ipairs(Vendor.stock(v, Quest.shelfRung(shut, v))) do
                assert(e.locked, v .. " sells " .. e.id .. " to a company it has never worked with")
            end

            local open = company(v, true, 99)
            local bottom, above = 0, 0
            for _, e in ipairs(Vendor.stock(v, Quest.shelfRung(open, v))) do
                if not e.locked then
                    if (e.unlockQuests or 0) == 0 then bottom = bottom + 1 else above = above + 1 end
                end
            end
            assert(bottom > 0, v .. " opened its door onto an empty shelf")
            assert(above == 0, v .. " handed over " .. above .. " wares above its bottom band")
        end
    end },

    { name = "a finished errand dots the wares it opened, on its own door", fn = function()
        -- WHAT THE WORK WAS FOR, said somewhere the player is standing. An errand pays out on a descent
        -- floor rather than through Quest.complete, so the shelf it opened used to open in silence: no
        -- unseen mark on the new rows, no dot on the house, and a shelf forty rows deep to find them in.
        local v = "arcanum"
        local p = company(v, false, 99)
        p.newStock = {}
        assert(not Vendor.hasMarkedStock(v, p.newStock), "an unrun house has nothing unread on it")

        local ok, opened = Errand.complete(p, Errand.opener(v))
        assert(ok, "the opener is run")
        assert(opened and #opened.items > 0, "and it opened the bottom band")
        assert(opened.vendorId == v and opened.vendor ~= v, "named by its shop name, for whoever says it")
        for _, entry in ipairs(opened.items) do
            assert(Player.isNew(p, Player.NEW_STOCK, entry.id),
                entry.id .. " came on sale, so it must carry the mark the shop draws")
        end
        assert(Vendor.hasMarkedStock(v, p.newStock), "and the house's own door wears the dot")
        assert(not Vendor.hasMarkedStock("bastion", p.newStock), "a house that sells none of it does not")

        for id in pairs(p.newStock) do Player.seeNew(p, Player.NEW_STOCK, id) end
        assert(not Vendor.hasMarkedStock(v, p.newStock), "and reading the shelf takes the dot off")
    end },

    { name = "a house's door speaks once, for work or for wares", fn = function()
        -- ONE QUESTION, THREE BOARDS: the market square, its shop cards, and the Markets card out in the
        -- city that wears the OR of all seven. The two halves clear differently, which is the whole
        -- reason the dot can say either thing -- a request goes out when it is TAKEN ON, a shelf when
        -- its rows have been read.
        local v = "arcanum"
        local p = company(v, false, 99)
        p.newStock = {}
        assert(not Errand.doorBadge(p, v, 99), "a shut house asks nothing and holds nothing")
        assert(not Errand.doorBadge(p, nil, 99), "and a card with no shelf behind it never dots")

        Errand.complete(p, Errand.opener(v))
        assert(Errand.doorBadge(p, v, 99), "the wares it opened are unread, so the door speaks")
        for id in pairs(p.newStock) do Player.seeNew(p, Player.NEW_STOCK, id) end

        assert(Errand.offered(p, v, 99), "and it is deep enough to be asked for the next one")
        assert(Errand.doorBadge(p, v, 99), "so the door still speaks, for the work this time")
        Errand.accept(p, Errand.next(p, v), 4)
        assert(not Errand.doorBadge(p, v, 99), "taking it on is what puts that half out")
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

    { name = "the tile knows whose work it is, and which of the two meetings this is", fn = function()
        -- The two ways a company meets a house's work, told apart because they are two different
        -- scenes: the job asked for over a counter, and the posting from a house with no counter yet.
        local v = "bastion"
        local opener = Errand.opener(v)

        local shut = company(v, false, 3)
        local found = Errand.posting(shut, opener)
        assert(found, "the opener is lying on the floor and reads as nothing")
        assert(found.kind == "found", "a house with no door cannot have asked: " .. found.kind)
        assert(found.vendorId == v, "the posting names the wrong house: " .. tostring(found.vendorId))

        local open = company(v, true, 6)
        local id = Errand.next(open, v)
        assert(id, v .. " has nothing left to ask for")
        -- NEVER ASKED FOR IS NOT A POSTING. A house sponsors far more work than it ever asks for, and
        -- a job the player has not taken on is not standing on any floor to be met.
        assert(Errand.posting(open, id) == nil, id .. " is a posting before anybody asked for it")

        Errand.accept(open, id, 6)
        local asked = Errand.posting(open, id)
        assert(asked and asked.kind == "asked", "an accepted errand does not read as asked for")
        assert(asked.def == Quest.defs[id], "the posting carries the wrong blueprint")

        -- Finished reads as neither, which is what a resumed run needs: the same job can be seated on
        -- a floor that was generated before it was run, and asking whether to take on work already
        -- done is a scene about nothing.
        open.completedQuests[id] = true
        assert(Errand.posting(open, id) == nil, "a finished errand is still being offered")
        -- The stair carries no quest at all, and is the end every floor has.
        assert(Errand.posting(open, nil) == nil, "an end with no quest on it reads as somebody's work")
    end },

    { name = "the scene that asks names the house and reads the posting out, whoever is standing there", fn = function()
        -- WHAT THE PLAYER IS OWED BEFORE THE FIGHT: whose work this is, what it says, and both answers.
        -- Every part of it fails silently -- a scene that names no house is a fight for a stranger, and
        -- a scene with one answer is not a question.
        local Conversation = require("models.conversation")

        for _, kind in ipairs({ "asked", "found" }) do
            local id = Errand.postingScene({ vendorId = "bastion", kind = kind })
            local def = id and Conversation.defs[id]
            assert(def, "no scene asks about a " .. kind .. " errand: " .. tostring(id))

            -- The house and its posting have to be on UNGATED lines. Every other line in these scenes
            -- is a companion's, and a company that lost her still has to be told what it is standing on.
            local plain = {}
            local answers = {}
            local asks = 0
            for _, node in ipairs(def.script or {}) do
                if not node.script then plain[#plain + 1] = node[2] or node.text or "" end
                if node.choices then
                    asks = asks + 1
                    for _, choice in ipairs(node.choices) do
                        assert(choice.answer, id .. ": an option that answers nothing")
                        answers[choice.answer] = true
                    end
                end
            end
            local said = table.concat(plain, " ")
            assert(said:find("{house}", 1, true), id .. " never names the house")
            assert(said:find("{posting}", 1, true), id .. " never says what the work is")
            assert(asks == 1, id .. " asks " .. asks .. " questions; the scene is one question")
            assert(answers.accept and answers.decline, id .. " does not offer both answers")
        end
    end },

    { name = "one scene speaks for all seven houses, off the posting set on the player", fn = function()
        -- The tokens the scenes are written against (models/locale.lua). A `%` in an authored
        -- description is the case that matters: substituted as a plain replacement string it would be
        -- read as a capture reference and come back mangled.
        local Locale = require("models.locale")
        local was = Player.active
        local p = Player.new()
        p.postingHouse = "The Bastion"
        p.postingWork = "Highwatch is 100% besieged. Get the column up the mountain."
        Player.active = p
        local out = Locale.substitute("{house} posted this. {posting}")
        Player.active = was
        assert(out == "The Bastion posted this. Highwatch is 100% besieged. Get the column up the mountain.",
            "the posting did not survive substitution: " .. out)
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
