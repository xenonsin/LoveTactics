-- Tests for the hub-city data layer: building registry discovery, ordering and
-- prestige-based unlocking, quest discovery and availability filtering, and
-- blueprint immutability.

local Building = require("models.building")
local Quest = require("models.quest")
local Player = require("models.player")

-- specs build a throwaway player pinned to the standing under test.
--
-- Standing is a COUNT of finished quests now (Player.standing) rather than a stored number, so it is
-- built rather than assigned. Synthetic ids: one that is not in Quest.defs moves the count and nothing
-- else, where a real id would drag its sponsor into Quest.sponsorProgress and open a shelf.
local function standingOf(n, ...)
    local done = {}
    for i = 1, math.max(0, (n or 1) - 1) do done["_standing_filler_" .. i] = true end
    -- Real quest ids on top of the filler, for a case that needs BOTH a standing and a specific quest
    -- finished (a quest-gated door). Passed separately because the two do different jobs: the filler
    -- only moves the count, these are looked up.
    for _, id in ipairs({ ... }) do done[id] = true end
    return done
end

local function playerAt(standing)
    local p = Player.new()
    p.completedQuests = standingOf(standing)
    return p
end

return {
    {
        name = "building registry discovers def files by filename",
        fn = function()
            -- The two doors that are not counters...
            assert(Building.defs.the_gate, "the_gate missing")
            assert(Building.defs.armory, "armory missing")
            -- ...and two of the seven houses. The rooms the city used to spend cards on -- the Market,
            -- the Cafe, the Inn, the Forge, the Touchstone, the Dueling Grounds -- are lines on those
            -- desks now (models/counter.lua), so their blueprints are gone and this list names houses.
            assert(Building.defs.cathedral, "cathedral missing")
            assert(Building.defs.undercroft, "undercroft missing")
            assert(not Building.defs.market, "the Market is a room behind the Undercroft, not a card")
            assert(not Building.defs.houses, "the Houses card went with the second board")
        end,
    },
    {
        name = "Building.list is sorted by order",
        fn = function()
            local list = Building.list(1)
            for i = 2, #list do
                assert(list[i - 1].order <= list[i].order,
                    "list not sorted at index " .. i)
            end
            -- FIRST IS THE FRONT DOOR, and which card that is has now changed three times -- the Quest
            -- Board, then the Rift, then the Bounty Board, and back. So what this line pins is the
            -- RULE rather than a favourite: whatever the city's way out is currently called, it sorts
            -- ahead of every room you visit before or after using it. Under a distance run that is the
            -- stair (data/buildings/the_gate.lua).
            assert(list[1].id == "the_gate",
                "the Rift should sort first: it is the city's front door, and order 1 is what says so")
        end,
    },
    {
        name = "Building.list computes locked from prestige",
        fn = function()
            -- Every gate that is a DEED rather than a threshold (models/building.lua). Each is a
            -- separate question asked below, and a bare prestige number cannot answer any of them, so a
            -- door on one is locked here whatever its threshold and this case has nothing to say about
            -- it. Listed rather than spelled out one by one, so a sixth kind of deed added to the model
            -- and forgotten here fails loudly instead of quietly widening what this case claims.
            local deeds = { "unlockQuest", "unlockExpeditions", "unlockUnidentified",
                "unlockClassLevel", "unlockAnyHouse", "unlockWound" }
            for _, b in ipairs(Building.list(1)) do
                local def = Building.defs[b.id]
                local onDeed = false
                for _, field in ipairs(deeds) do
                    if def[field] then onDeed = true end
                end
                -- ...and a house, whose door is the OR of the rooms behind it (models/offer.lua). Every
                -- one of those rooms is on a deed of its own -- a class level, a wound, a floor count --
                -- so a bare prestige number cannot answer for it either.
                if def.offers then onDeed = true end
                if not onDeed then
                    assert(b.locked == (1 < b.unlockPrestige),
                        b.id .. " locked flag wrong at prestige 1")
                end
            end
        end,
    },
    {
        -- Some doors are opened by a deed rather than by getting richer, and `unlockQuest` is the older
        -- of the two ways to say so. NO SHIPPED BUILDING USES IT ANY MORE: it named campaign quests, the
        -- board is retired, and the last card standing on one (the Dueling Grounds) was moved onto a
        -- circle for exactly that reason -- a gate naming a deed nobody can perform is a card that never
        -- opens. So the rule is pinned through a def of the spec's own rather than through the city.
        --
        -- Worth keeping despite having no subject: the gate is the campaign's, parked with the rest of
        -- it (Building.RETIRED), and bringing the board back must not find it quietly rotted.
        name = "a quest-gated building stays shut until that quest is done",
        fn = function()
            local id = "_spec_quest_gated"
            Building.defs[id] = {
                name = "Spec Hall", order = 99, x = 0, y = 0, w = 10, h = 10,
                unlockPrestige = 1, unlockQuest = "quest_colosseum_slot_01",
            }

            local function findIn(list)
                for _, b in ipairs(list) do
                    if b.id == id then return b end
                end
            end

            local ok, err = pcall(function()
                local before = findIn(Building.list({ completedQuests = standingOf(9) }))
                assert(before, "a quest-gated door should be listed even while shut")
                assert(before.locked, "no amount of prestige should open a quest-gated door")

                local after = findIn(Building.list({ completedQuests = standingOf(1, "quest_colosseum_slot_01") }))
                assert(not after.locked, "finishing the named quest should open it, at any prestige")

                -- And a bare prestige number -- what every older caller passes -- cannot open one,
                -- because it has no way to know.
                assert(findIn(Building.list(9)).locked,
                    "a prestige number alone should never open a quest gate")
            end)

            Building.defs[id] = nil -- the registry is shared; leave the city as it was found
            assert(ok, err)
        end,
    },
    {
        -- THE ONE DOOR THAT OPENS ON SOMEBODY ELSE'S WORK. The Dueling Grounds keep no shelf and post no
        -- errands, and were gated on the Colosseum debut -- a quest that went with the board, leaving
        -- the card shut forever while advertising a prestige number that was not even the gate being
        -- asked. The sand is the Colosseum's own first job now, which is the same sentence with a deed
        -- behind it that the player can actually reach.
        name = "the duel opens on the sand, and the sand is the Colosseum's first job",
        fn = function()
            local Errand = require("models.errand")
            local Offer = require("models.offer")
            -- IT IS A ROOM NOW, NOT A CARD. The Dueling Grounds stood on the plaza and were the only
            -- door that named somebody ELSE'S errand -- this house's opener -- which is a card that
            -- exists to point at another card. It is a line on the Colosseum's own desk
            -- (data/buildings/colosseum.lua), and the gate behind it did not change.
            assert(not Building.defs.dueling_grounds, "the Dueling Grounds are a room, not a card")
            local colosseum = Building.defs.colosseum

            local function duelOpen(player)
                return Offer.openSet(player, colosseum).duel == true
            end

            assert(not duelOpen({ completedQuests = standingOf(20) }),
                "no amount of standing should open the duel")
            assert(duelOpen({ completedQuests = { [Errand.opener("colosseum")] = true } }),
                "running the Colosseum's opener should open the duel")
            -- ...and it is the Colosseum's job specifically, not any house's.
            assert(not duelOpen({ completedQuests = { [Errand.opener("arcanum")] = true } }),
                "another house's opener should not open the duel")

            -- The HOUSE, meanwhile, is open either way -- its shelf answers to a fighter level, and a
            -- door opens on any room behind it. What the opener buys is the line, not the plate.
            local sandy = { completedQuests = { [Errand.opener("colosseum")] = true } }
            for _, b in ipairs(Building.list(sandy)) do
                if b.id == "colosseum" then
                    assert(not b.locked, "the sand should stand the Colosseum's door open")
                end
            end
        end,
    },
    {
        -- A SHUT DOOR SAYS NOTHING, and that is the decision rather than an omission. The card carried a
        -- sentence for an afternoon -- composed off whichever gate was really being asked -- and it was
        -- the right fix for one quoting prestige, a currency the city stopped counting. It is the wrong
        -- one now: every shut shop has the SAME answer (go down, walk the floors, the work is lying on
        -- one of them), so a per-card sentence was seven copies of one instruction, and naming the house
        -- in it gave away the shop the card exists to withhold.
        --
        -- Pinned because the field going quiet is invisible: a `requirement` left on the entry would
        -- simply never be drawn, and would rot.
        name = "a shut door carries no sentence to draw",
        fn = function()
            for _, b in ipairs(Building.list(Player.new())) do
                assert(b.requirement == nil,
                    b.id .. " carries a requirement string that nothing draws")
            end
            assert(Building.requirement == nil,
                "Building.requirement has no reader; it should not have survived the card that read it")
        end,
    },
    {
        -- THE POSTING IS SEATED WHERE IT CAN BE FOUND, which is the half of the recruit that lives in
        -- the descent. A companion nobody is ever shown is a body that can never join.
        name = "a house whose companion is unrecruited posts on a floor, and a done one posts nothing",
        fn = function()
            local Descent = require("models.descent")
            local Errand = require("models.errand")

            -- A COMPANION IS MET AT THEIR COUNTER FIRST, so a company that has visited nobody is
            -- offered nobody. This one has walked into every house -- and has Saber already, because she
            -- is scripted onto floor one until she joins and the roll never runs while she is outstanding
            -- (Descent.SCRIPTED_COMPANION). What is being seated here is a ROLLED posting.
            local p = Player.new()
            p.completedQuests = { [Errand.opener(Descent.SCRIPTED_COMPANION)] = true }
            for vendorId in pairs(Errand.houses()) do Player.markVendorVisited(p, vendorId) end

            -- ONE PER DESCENT, on a floor the run rolls for (Descent.dealCompanion). It was one per
            -- FLOOR, a permutation dealt across the first six -- which made the roster fill itself on a
            -- schedule whether or not the player went looking.
            local run, dealt
            for seed = 4242, 4400 do
                run = Descent.new(p, seed)
                if run.companion then dealt = run.companion break end
            end
            assert(dealt, "no seed in 159 offered anybody to a company that has met every house")

            local seen = 0
            for floor = 1, Descent.FLOORS do
                local here = Descent.openersAt(run, floor)
                assert(#here <= 1, "floor " .. floor .. " carries " .. #here .. " companions, not one")
                seen = seen + #here
            end
            assert(seen == 1, "a descent offers one companion; this one offered " .. seen)
            -- The Bastion is what the gate is for: it names Rowan, who is sworn in the prologue, so its
            -- posting recruits nobody and must never be dealt.
            assert(dealt.house ~= "bastion", "the Bastion posts a recruit for a body already in the company")

            -- The seating itself: a shut house's opener is one more end on the board, and it stops being
            -- one the moment that door is open.
            local function endsOn(player, floor)
                local sin = Descent.sinAt(run, floor)
                local ids = {}
                for _, spec in ipairs(Descent.floorObjectives(player, floor, sin, 1, false, run)) do
                    if spec.questId then ids[spec.questId] = true end
                end
                return ids
            end

            local opener = Errand.opener(dealt.house)
            assert(endsOn(p, dealt.floor)[opener],
                dealt.house .. "'s opener is not on floor " .. dealt.floor .. ", which posts it")

            p.completedQuests[opener] = true
            assert(not endsOn(p, dealt.floor)[opener],
                "a house whose companion has joined is still posting the job that recruited her")
        end,
    },
    -- ("the city's front door is the Gate, and the board is parked rather than cut" stood here. It
    -- pinned the board as RETIRED-not-deleted: its blueprint still on disk, hidden by one entry in
    -- Building.RETIRED, so bringing the campaign back was a one-line change. The board is CUT now --
    -- panel, blueprint, Quest.available, Quest.board and the season table -- so there is no parked
    -- thing left to assert. The Gate standing alone in the plaza is covered by the case below, which
    -- counts the doors the city opens on.)
    {
        -- THE CITY GROWS ON WHAT THE COMPANY HAS DONE. Six of the eight cards on the plaza do nothing
        -- on a fresh save -- there is no shelf worth browsing before anything has been carried out of the
        -- rift, no supper worth buying for a road nobody has walked and nothing in the bag to forge -- so
        -- each arrives on the deed that gives it a job. Pinned card by card, because the whole value of
        -- the staging is the ORDER.
        name = "the plaza opens on its two ways out, and the rest arrive on the deeds that give them work",
        fn = function()
            local Descent = require("models.descent")
            local Errand = require("models.errand")
            local Wound = require("models.wound")

            local function shut(who, id)
                for _, b in ipairs(Building.list(who)) do
                    if b.id == id then return b.locked end
                end
                error(id .. " is not a card in the city at all")
            end

            -- A FRESH SAVE OPENS ON TWO: look at what the company carries, and go down.
            local fresh = Player.new()
            local open = {}
            for _, b in ipairs(Building.list(fresh)) do
                if not b.locked then open[#open + 1] = b.id end
            end
            table.sort(open)
            -- THE MARKET IS THE ONE THAT LEFT. It stood open on the first morning for a long
            -- time on the argument that a shelf of unaffordable things teaches the ladder -- but a
            -- counter deals a ware only once the class has grown into it, so the shop it opened onto
            -- was mostly locked rows anyway (data/buildings/market.lua). (This read "only once the
            -- company has carried one out" until 2026-09-20: the discovery gate, gone since
            -- 2026-09-19. The conclusion is unchanged -- a first-morning rack is mostly shut either
            -- way -- which is exactly why nothing caught the sentence going stale.) It arrives on the first
            -- descent with the rest of them.
            --
            -- THE STAIR IS THE ONLY WAY OUT ON THE FIRST MORNING, and the armory is the only thing to
            -- do before taking it. That is the whole of what this line pins.
            --
            -- THE BOUNTY BOARD IS PARKED (2026-09-18) and its card is deleted, so there is no second
            -- door -- but note that this assertion would have stayed green either way, because while
            -- the board was live it stood in the HOUSES district and this walk only lists `city`. The
            -- three paragraphs that used to stand here narrated the board arriving, leaving, and
            -- leaving again, in a case that could not see it. A comment that tracks a system the
            -- assertion beneath it never touches is prose with nothing holding it honest, and it drifted
            -- twice before anybody noticed.
            --
            -- Why it went is in docs/bounties.md: its seven postings are the seven quests
            -- models/errand.lua already seats on floors of the rift. models/bounty.lua stays on disk,
            -- and one file undoes it.
            -- ...AND THE HOUSE THE COMPANY IS ALREADY STANDING IN. The starting roster is Rowan, who
            -- is a knight, and a house announces to a company training for what it sells
            -- (models/offer.lua's `declared` gate) -- so the Bastion is on the first morning's plaza on
            -- purpose. It is the shop for the gear the player is already carrying; making them wait
            -- three trips for it was the room queue pacing a CLASS, which is not a thing rooms know how
            -- to do. tests/class_house_spec.lua is that rule in full.
            assert(table.concat(open, ",") == "armory,bastion,the_gate",
                "a fresh city opens on the armory, the stair and the starting class's house; got " ..
                table.concat(open, ", "))

            -- ...and take the knight away and it is the two again, which is what says the third card is
            -- the gate above doing its job rather than the Bastion having quietly come ungated.
            local classless = Player.new()
            classless.roster = {}
            local bare = {}
            for _, b in ipairs(Building.list(classless)) do
                if not b.locked then bare[#bare + 1] = b.id end
            end
            table.sort(bare)
            assert(table.concat(bare, ",") == "armory,the_gate",
                "a company in no class at all opens on the two ways out; got " ..
                table.concat(bare, ", "))

            -- NONE OF THESE IS A CARD ANY MORE, and their absence is asserted rather than assumed --
            -- `shut` raises on a card the city does not have, which is exactly the answer wanted. Each
            -- is a room on a house's desk now (models/counter.lua), and the gate each carried came with
            -- it: what follows pins the gates where they actually live.
            for _, id in ipairs({ "the_inn", "the_ward", "market", "cafe", "forge",
                                  "the_touchstone", "dueling_grounds", "houses" }) do
                assert(not pcall(shut, Player.new(), id), id .. " is still a card in the city")
            end

            -- ONE ROOM PER TRIP HOME, and the clock is trips rather than depth (models/offer.lua's
            -- `trips` gate). Depth is bursty: a company that pushed to floor four on its first
            -- descent used to come home to four doors at once, and one that farmed floor one froze
            -- its city forever. Asked of the ROOM rather than of the door it is behind, because a
            -- house's door is the OR of everything it holds.
            local Offer = require("models.offer")
            local rooms = {
                { house = "undercroft",    room = "counter",  need = 1 },
                { house = "hunters_lodge", room = "supper",   need = 2 },
                { house = "bastion",       room = "forge",    need = 3 },
                { house = "arcanum",       room = "bestiary", need = 4 },
                { house = "arcanum",       room = "study",    need = 5 },
            }
            for _, r in ipairs(rooms) do
                for trip = 0, r.need do
                    local p2 = Player.new()
                    p2.runsStarted = trip
                    local open = Offer.openSet(p2, Building.defs[r.house])[r.room] == true
                    assert(open == (trip >= r.need),
                        r.room .. " reads the wrong way with the company at trip " .. trip)
                end
            end

            -- NO TWO OF THEM LAND TOGETHER, which is the whole point of the unit. Walked rather than
            -- asserted per pair, so a room added on a colliding count fails here rather than in a
            -- playtest.
            local seenAt = {}
            for _, r in ipairs(rooms) do
                assert(not seenAt[r.need],
                    r.room .. " arrives on the same trip as " .. tostring(seenAt[r.need]))
                seenAt[r.need] = r.room
            end

            -- The record is the COMPANY's rather than the run's (models/descent.lua's Descent.reached),
            -- so climbing out and going back down shallow cannot take a room away again.
            local deep = Player.new()
            deep.runsStarted = 6
            assert(Offer.openSet(deep, Building.defs.bastion).forge,
                "the trip count only ever climbs, so a room it opened stays open")

            -- NONE OF THEM IS ON A PRESTIGE GATE any more, which is the half that would rot silently:
            -- standing 20 is past every threshold this city has ever had.
            local decorated = Player.new()
            decorated.completedQuests = standingOf(20)
            for _, r in ipairs(rooms) do
                assert(not Offer.openSet(decorated, Building.defs[r.house])[r.room],
                    r.room .. " opened on standing rather than on its deed")
            end

            -- ...NOR ON DEPTH, which is the axis this schedule was moved OFF. A company that dived to
            -- floor nine on one trip has seen ONE homecoming and must have exactly one new room.
            local diver = Player.new()
            Descent.reached(diver, 9)
            diver.runsStarted = 1
            local got = {}
            for _, r in ipairs(rooms) do
                if Offer.openSet(diver, Building.defs[r.house])[r.room] then got[#got + 1] = r.room end
            end
            assert(#got == 1 and got[1] == "counter",
                "one trip home is one room, however deep it went; got " .. table.concat(got, ", "))

            -- THE MENDING ON THE FIRST BODY CARRIED UP BROKEN, which is the one gate that is not a floor
            -- count -- and the one room the first morning still teaches (states/hub.lua's coachingMend).
            local hurt = Player.new()
            assert(not Offer.openSet(hurt, Building.defs.cathedral).mend,
                "nobody is hurt, so there is nothing to mend")
            Wound.inflict(hurt, { { id = "character_rowan" } })
            assert(Offer.openSet(hurt, Building.defs.cathedral).mend,
                "a wound did not put the mending on the Cathedral's desk")
        end,
    },
    {
        -- THE SEVEN SHELVES, AND THE CARD/ROOM SPLIT THAT REPLACED THEIR GATE.
        --
        -- Each shelf used to carry `classLevel = 1` -- level 1 of the house's own class, in any body on
        -- the roster -- and that gate decided TWO things while the shelf was the only room behind its
        -- door: whether you could shop, and whether the shopfront existed. The fold gave every house a
        -- second room and the plaza started drawing doors for THOSE, so the two came apart and the gate
        -- was left answering only the first: the Undercroft stood open on the market from the first trip
        -- home with no shop behind it, for any company without a rogue -- which is every company, since
        -- the roster starts as one knight.
        --
        -- So the shelf is ungated and the CARD is held back by `quiet` instead, and this case pins both
        -- halves. It is asserted in both directions because the failure was silent either way: a gated
        -- shelf is a shopfront with no shop, and an unquiet one is seven plates on the first morning.
        name = "a house's SHELF is always behind its door, and its CARD waits on a deed",
        fn = function()
            local Character = require("models.character")
            local Class = require("models.class")
            local Offer = require("models.offer")
            local Quest = require("models.quest")
            local Wound = require("models.wound")

            local function shut(who, id)
                for _, b in ipairs(Building.list(who)) do
                    if b.id == id then return b.locked end
                end
                error(id .. " is not a card in the city")
            end
            local function shelfOpen(who, id)
                return Offer.openSet(who, Building.defs[id]).shelf == true
            end

            -- Every house names a vendor, that vendor names a class, and the house carries a desk with
            -- rooms behind it. The class is still load-bearing with the gate gone -- Quest.shelfRung
            -- reads it for the RUNG -- so a vendor without one is a shelf frozen at its bottom band.
            local Vendor = require("models.vendor")
            local houses = 0
            for id, def in pairs(Building.defs) do
                if def.counter then
                    houses = houses + 1
                    local vdef = def.vendor and Vendor.defs[def.vendor]
                    assert(vdef, id .. " is a house with no vendor blueprint")
                    assert(vdef.class, id .. "'s vendor names no class, so its shelf can never deepen")
                    assert(def.offers and #def.offers > 0, id .. " is a house with no rooms behind it")
                    local shelf
                    for _, offer in ipairs(def.offers) do
                        if offer.answer == "shelf" then shelf = offer end
                    end
                    assert(shelf, id .. " keeps no shelf")
                    assert(shelf.gate == nil,
                        id .. "'s shelf is gated; a shopfront that offers no shop is not a shopfront")
                    assert(shelf.quiet == true,
                        id .. "'s shelf is not quiet, so browsing alone would put its card on the plaza")
                end
            end
            assert(houses == 7, "the city is supposed to hold seven houses; it holds " .. houses)

            -- ON A FRESH SAVE: every shelf OPEN, every card SHUT. The two questions, at the one moment
            -- they most obviously differ -- nothing has been climbed, nobody is hurt, nothing has been
            -- carried up unread and the stair has not been walked.
            --
            -- ONE CARD IS EXEMPT AND IT IS DERIVED, NEVER NAMED: the house that shelves a class the
            -- company is standing in announces itself (models/offer.lua's `declared` gate), and the
            -- starting roster is a knight. Naming "bastion" here would pin the starting company rather
            -- than the rule, and would go quietly false the day somebody else is handed to the player
            -- first -- so this asks Vendor.shelves the same question the gate does.
            local fresh = Player.new()
            local taken = Class.takenSet(fresh)
            for id, def in pairs(Building.defs) do
                if def.counter then
                    assert(shelfOpen(fresh, id), id .. "'s shelf is shut on a fresh save")
                    local training = false
                    for class in pairs(taken) do
                        if Vendor.shelves(Vendor.defs[def.vendor], class) then training = true end
                    end
                    if training then
                        assert(not shut(fresh, id),
                            id .. " shelves what the company is standing in and must be on the plaza")
                    else
                        assert(shut(fresh, id), id .. "'s card is on the plaza on a fresh save")
                    end
                end
            end

            -- AND THE OPEN SHELF IS NOT AN EMPTY ROOM. Ungating it is only an improvement if rung 0
            -- stocks something -- Quest.shelfRung's own header says level 0 IS rung 0, "the class's
            -- bottom band", which under the level-1 gate no player could ever reach. Asserted of every
            -- house, because a house whose bottom band is all locked rows is the old bug wearing a shop.
            for id, def in pairs(Building.defs) do
                if def.counter then
                    local gates = Quest.shelfGates(fresh, def.vendor)
                    assert(gates.rung == 0, id .. " does not sit at rung 0 for a company with no class")
                    local buyable = 0
                    for _, row in ipairs(Quest.shelf(fresh, def.vendor) or {}) do
                        if not row.locked then buyable = buyable + 1 end
                    end
                    assert(buyable > 0, id .. "'s rung-0 shelf has nothing on it a fresh company can buy")
                end
            end

            -- A CLASS LEVEL BUYS DEPTH NOW, not the door. One body, one class, one level: the rung the
            -- Bastion's shelf reads climbs, and the plaza does not move.
            --
            -- THE AVATAR RATHER THAN ROWAN, and the swap is the whole point of the case rather than a
            -- convenience. What opens a house is the company STANDING IN a class it shelves -- an
            -- identity (models/offer.lua's `declared`) -- and Rowan is a knight before a single point is
            -- banked, so running this on her would prove nothing about the level. The avatar was trained
            -- in nothing in particular and stands in no class at all, so what moves here is the ledger
            -- and only the ledger.
            local knight = Player.new()
            knight.roster = { Character.instantiate("character_avatar") }
            assert(Class.declaredOf(knight.roster[1]) == nil,
                "the avatar stands in no class; a body that does would open its house and hide the claim")
            Character.recordTechnique(knight.roster[1], "knight", Class.classLevelCost(1))
            assert(Quest.shelfRung(knight, "bastion") == 1, "knight 1 did not raise the Bastion's rung")
            assert(Quest.shelfRung(knight, "arcanum") == 0, "knight 1 raised the mages' rung as well")
            assert(shut(knight, "bastion"), "a class level must not put a card on the plaza")
            assert(shut(knight, "arcanum"), "and its neighbour's with it")

            -- ...AND THE OTHER HALF, on the same body, so the two mechanisms are told apart here rather
            -- than only in tests/class_house_spec.lua: TAKING UP the class does open the card, and the
            -- rung it was standing at is untouched by that.
            knight.roster[1].declaredClass = "knight"
            assert(not shut(knight, "bastion"),
                "declaring the class must put the house that teaches it on the plaza")
            assert(Quest.shelfRung(knight, "bastion") == 1,
                "...and declaring is not a rung: what you buy is the door, not the depth")

            -- ANY body on the roster, not the one standing in front of you: a shelf is bought from with
            -- one purse into one stash, so the company's deepest holder is what the rung asks about.
            local pair = Player.new()
            pair.roster = { Character.instantiate("character_kaya"), Character.instantiate("character_rowan") }
            Character.recordTechnique(pair.roster[2], "priest", Class.classLevelCost(1))
            assert(Quest.shelfRung(pair, "cathedral") == 1, "a second body's class level did not count")

            -- A hair under the rung does not count: the reading is the LEVEL, not the technique banked
            -- toward it.
            local nearly = Player.new()
            nearly.roster = { Character.instantiate("character_rowan") }
            Character.recordTechnique(nearly.roster[1], "rogue", Class.classLevelCost(1) - 1)
            assert(Quest.shelfRung(nearly, "undercroft") == 0, "a rung short of rogue 1 counted anyway")

            -- WHAT PUTS A CARD ON THE PLAZA is the deed a player can feel. A company walks out of Act 0
            -- with Rowan hurt and no priest in the world: the mending opens, and the Cathedral's door
            -- with it -- or the only bone-setting in the game is behind a class nobody has.
            local hurt = Player.new()
            Wound.inflict(hurt, { { id = "character_rowan" } })
            assert(not shut(hurt, "cathedral"), "a wound must stand the Cathedral's door open")
            assert(shut(hurt, "colosseum"), "and must not open anybody else's")
        end,
    },
    {
        -- ONE CARD TO A SLOT, ON EITHER BOARD. The Ward shipped on (175, 120) -- the Houses' rect -- and
        -- the collision is invisible in the data: two blueprints, two unique `order`s, two different
        -- gates, nothing to read wrong. On the screen it was one plate with two labels in it, and the
        -- worse half is WHICH label won: the shut card draws its "???" last (ui/building_map.lua), so
        -- the locked door hid the open one's name and the coach bubble pointed at a card that read
        -- "???" while telling the player to click the Ward.
        --
        -- Asked of every pair on a board rather than of the known slots, because the failure is two
        -- cards agreeing, not a card being off-grid: a future pair that shares some other rect is the
        -- same bug and this catches it without being taught the layout. Overlap rather than equality
        -- for the same reason -- the middle column is wider than the ring, so a card can collide with
        -- a neighbour without matching it.
        name = "no two cards share a slot, and the nine fill the ring exactly",
        fn = function()
            local function overlaps(a, b)
                return a.x < b.x + b.w and b.x < a.x + a.w
                   and a.y < b.y + b.h and b.y < a.y + a.h
            end
            -- Every card on the board, open or shut: Building.list flags a locked plate rather
            -- than dropping it, and a locked plate is drawn, so it collides like any other.
            local cards = Building.list(Player.new())
            for i = 1, #cards do
                for j = i + 1, #cards do
                    assert(not overlaps(cards[i], cards[j]),
                        cards[i].id .. " and " .. cards[j].id ..
                        " sit on the same slot; the shut one's \"???\" draws over the other's name")
                end
            end
            -- NINE CARDS, NINE SLOTS. The lattice is three by three with the Rift in the taller middle
            -- one, which leaves eight in the ring -- the Armory and one per house. Pinned because the
            -- fit being exact is what the fold bought, and a tenth card would have nowhere to go but on
            -- top of a neighbour (the failure above, which has shipped once).
            assert(#cards == 9, "the plaza holds nine cards; it holds " .. #cards)
        end,
    },
    {
        name = "quest registry discovers def files by filename",
        fn = function()
            assert(Quest.defs.quest_bastion_slot_01, "quest_bastion_slot_01 missing")
            assert(Quest.defs.quest_colosseum_slot_01, "quest_colosseum_slot_01 missing")
        end,
    },
    -- (Four cases stood here, all about what the BOARD would show: that Quest.available gated on
    -- prestige AND standing rather than either alone, that a quest which had not asked to be shown
    -- locked was hidden instead, that the Gate Below waited for all seven generals before taking a row,
    -- and that listing and availability left blueprints untouched.
    --
    -- Quest.available is gone with the board. The blueprint-immutability half is kept, asked of
    -- Building.list alone, because that is the mutation this file exists to catch.)
    {
        name = "blueprints are untouched after Building.list",
        fn = function()
            Building.list(3)
            local named = Building.defs.the_gate.name
            Building.list(1)
            assert(Building.defs.the_gate.name == named, "building name changed")
            assert(Building.defs.the_gate.locked == nil, "building blueprint mutated")
        end,
    },
}
