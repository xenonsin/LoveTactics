-- ERRANDS: the small pieces of work a house asks for. The FIRST one opens its door and the rest climb
-- its shelf, so a house is one ladder rather than a threshold with a ladder behind it.
--
-- THE DOOR USED TO BE THE CIRCLE, and that was the whole problem. A house opened when its sin fell --
-- floors 2, 4, ... 14, dealt in a different order every run -- and it asked for nothing at all until
-- then, because a house asks for work INSIDE ITS OWN SHOP. So the two gates ran in series on the same
-- currency: a house dealt sixth opened at floor twelve and then wanted fourteen more floors of errands
-- that do not exist. Six of the seven shelves were decorative in any given run, the disciplines behind
-- them were unreachable, and going deeper was the only way to equip a class -- which is backwards, since
-- depth is exactly what a company needs the gear FOR.
--
-- So the opener is something you FIND. It is seated on a floor unasked (Descent.floorObjectives), at its
-- own dead end off the path to the stair, and running it opens the door and counts as errand one. A
-- company that beelines the stair opens nothing; a company that walks the floor comes home with a shop.
-- Depth still decides how good a shelf is. It no longer decides whether a class can be equipped at all.
--
-- WHAT AN ERRAND IS, and why almost none of this is new content. It is one of the campaign's own quests
-- (data/quests/<house>/quest_<house>_slot_NN.lua), re-seated. Those blueprints already carry everything
-- an errand needs and nothing it does not:
--
--   sponsor            which house is asking
--   name/description   what to put on the card
--   intro/outro        the scenes where they ask and where they thank you
--   map.objective      the fight itself, composition and win condition
--   rewardGold/Items   what it pays
--
-- Seventy of them were sitting parked when the Quest Board was retired. Re-reading them as errands is
-- what makes the houses' shelves reachable again without authoring a second body of work -- and it is
-- why an errand reads as house-appropriate for free: the Bastion's errands are sieges and relief
-- columns because that is what the Bastion's quests always were.
--
-- ONE OR TWO ENCOUNTERS, NEVER A LEG. A campaign quest was a whole day out: its own ground, five stops,
-- a walk. An errand is its OBJECTIVE, seated on a descent floor as one more end among the floor's own --
-- exactly the shape Quest.trip already builds for a ground carrying several pieces of work, so the
-- generator, the board and the payout all take it unchanged.
--
-- WHAT IS DELIBERATELY DROPPED from the quest def: `requiredPrestige`, `requiredQuests` and the biome.
-- The first two are the campaign's own ladder and the third is a ground the descent does not travel to.
-- The chain that remains is the SLOT ORDER -- a house asks for its first errand before its second --
-- which is the only ordering that ever carried meaning.
--
-- Pure model: no love.graphics, no state switching. states/game.lua seats them, ui/panels/shop.lua
-- lists them, and this decides which one is being asked for and whether it is done.

local Quest = require("models.quest")
local Vendor = require("models.vendor") -- hasMarkedStock: the other half of what a house's door has to say

local Errand = {}

-- THE FLOORS THE LADDER IS LAID BETWEEN. The first rung is asked at floor 3 -- the doors are dealt over
-- the first circle and a house cannot ask before it is open -- and the last at floor 12, which leaves
-- the seventh circle and the Crown to spend the top of a shelf in.
--
-- THAT GAP IS THE POINT OF THE WHOLE RE-CUT. The ladder used to land its top rung on floor 14: you
-- bought the best gear the game sells and immediately fought the last thing in it. Three floors is the
-- room to find out what it does.
Errand.FIRST_ASK_FLOOR = 3
Errand.LAST_ASK_FLOOR = 11

-- THE DEEPEST FLOOR AN ERRAND CAN BE SEATED ON, which is the last circle's and not the bottom.
--
-- The Hollow Crown's floor builds exactly one end -- the Crown -- and never calls
-- Descent.floorObjectives, so an errand seated down there would be taken on and never appear on a board.
-- Read off the descent rather than typed, since it is that module's shape (seven circles, two floors
-- each) and not a number this one gets a say in. Required lazily: models/descent.lua reaches back into
-- this file, and neither should be the other's load-time dependency.
local function Descent()
    return require("models.descent")
end

local function deepestSeatableFloor()
    return Descent().CIRCLE_FLOORS
end

-- The ordered list of a house's errands, shallowest first. Sorted by ID because the slot number IS the
-- order -- `quest_bastion_slot_01` before `_02` -- and `pairs` over the registry is unspecified, so a
-- house would otherwise ask for its seventh errand first on some machines and not others.
--
-- A HOUSE ASKS FOR THE WORK THAT OPENS SOMETHING, and for nothing else. Two kinds qualify:
--
--   the OPENER      `slot_01`, which opens the door and the shelf's bottom rung
--   a GATE          any job a discipline hangs off (data/disciplines/*.lua's `requiredQuests`)
--
-- Everything else a house sponsors -- the plain numbered fights, the bounties -- is left where it is.
-- Not deleted: unasked. Point a discipline at one and it joins the ladder with no edit here.
--
-- WHY THIS IS THE LINE AND NOT "THE FIRST N BY NUMBER". A house's stock is a fixed 78 to 109 wares
-- however many rungs it is cut into, so twelve rungs meant two or three wares an errand at the bottom
-- of a shelf -- a job run for a tooltip. But cutting to a flat six by sort order took the Poisoned Glade
-- and the Shadowless with it, and shut the herbalist and the ninja out of the game: the descent is the
-- only mode there is, so a quest nobody is asked for is a quest nobody can finish. The jobs that open
-- something ARE the ladder, and there are six to eight of them per house -- which is the rung count the
-- shelf wanted anyway. `errand: every discipline's gate quest is still asked for` holds the floor.
--
-- IT IS SIX AT EVERY HOUSE TODAY -- one opener and five gates apiece, 35 gate quests carrying the 38
-- disciplines, since two may share a rung. This paragraph used to read "six at five of them, seven at
-- the Cathedral, eight at the Lodge"; the gates were evened out and the sentence was not, and a comment
-- describing a distribution the data no longer has is the kind of thing a reader trusts. Errand.tiers
-- is the answer, and it is counted rather than stated.
--
-- The count may differ by house again and nothing here objects: the disciplines are not obliged to be
-- evenly spread, Errand.floorFor staggers on whatever count it finds, and the forge ceiling divides by
-- it (models/forge.lua). What would be a problem is seven houses on one ladder asking for seven jobs on
-- the same floor, which is what the stagger below exists to prevent. See Errand.floorFor.
local gateCache
local function opensADiscipline(questId)
    if not gateCache then
        gateCache = {}
        for _, def in pairs(require("models.discipline").defs) do
            for _, id in ipairs(def.requiredQuests or {}) do gateCache[id] = true end
        end
    end
    return gateCache[questId] == true
end

local cache
function Errand.forVendor(vendorId)
    if not cache then
        cache = {}
        for id, def in pairs(Quest.defs) do
            if def.sponsor and def.map and def.map.objective
                and (id:match("_slot_01$") or opensADiscipline(id)) then
                cache[def.sponsor] = cache[def.sponsor] or {}
                table.insert(cache[def.sponsor], id)
            end
        end
        -- AN AUTHORED `ladder` WINS, and the id sort is what a house gets for not authoring one.
        --
        -- The order decides which rung each job is, and for most houses the ids already say it: the
        -- numbered slots run in order and the capstones follow. But that is alphabet, not design, and it
        -- cannot express a house whose spirit rung belongs ABOVE a numbered one -- `..._slot_05` sorts
        -- before `..._the_spirit_wood` and always will. The Lodge authors `ladder` on all six of its jobs
        -- for exactly that; the other six houses author none and sort as before.
        --
        -- The opener still leads a house with no authored order. Sorting on id alone put two capstones
        -- ahead of their own door (`..._apothecary_ren` and `..._champions_challenge` both sort before
        -- `..._slot_01`), so the ladder read as though a multiclass capstone were the rung a newcomer
        -- starts on. Errand.opener always named the right job; this is the LIST agreeing with it.
        for _, ids in pairs(cache) do
            table.sort(ids, function(a, b)
                local ar, br = (Quest.defs[a] or {}).ladder, (Quest.defs[b] or {}).ladder
                if ar and br and ar ~= br then return ar < br end
                local ao, bo = a:match("_slot_01$") ~= nil, b:match("_slot_01$") ~= nil
                if ao ~= bo then return ao end
                return a < b
            end)
        end
    end
    return cache[vendorId] or {}
end

-- How many rungs this house's shelf has, which is how many jobs it asks for. The grader spreads its
-- stock across slots 0..tiers-1 off this number (tools/grade_report.lua), so a rung of stock and the job
-- that opens it are the same thing counted from two ends and cannot drift apart.
function Errand.tiers(vendorId)
    return #Errand.forVendor(vendorId)
end

-- How many of this house's errands are finished. Reads the SAME ledger the shelf does
-- (`player.completedQuests`, counted per sponsor by Quest.sponsorProgress), so running an errand opens
-- stock through the machinery that already existed rather than a parallel tally that could disagree.
function Errand.done(player, vendorId)
    local n = 0
    for _, id in ipairs(Errand.forVendor(vendorId)) do
        if (player and player.completedQuests or {})[id] then n = n + 1 end
    end
    return n
end

-- The next errand this house has to ask for, or nil once its line is finished.
--
-- THE FIRST ONE NOT DONE, rather than the Nth by position, and the difference is the opener. That job is
-- run on a FLOOR before this house has a door to ask through (Errand.opener), and it is `slot_01` rather
-- than whatever sorts first -- so on a house whose line carries a story quest it sits partway down the
-- list. Counting positions would then hand back a job already finished, and later offer the opener again
-- as though the shop had never opened.
-- ...AND ONE WHOSE OWN PREREQUISITES ARE MET, which is what makes the cross-discipline chain real.
--
-- Twenty-one of the thirty-eight disciplines are MULTICLASS, and the job each hangs off names a subclass
-- gate of BOTH its parents in its own `requiredQuests` -- the Champion's card wants the Colosseum's third
-- and the Bastion's third, at two different houses. Handing that job over on line order alone would open
-- a capstone to a company that had never set foot in the other house, which is the one thing the
-- multiclass gate exists to prevent (tests/discipline_spec.lua reads the same chain from the other end).
--
-- ONLY PREREQUISITES THAT ARE THEMSELVES ASKED FOR, which is the whole of the rule. A chain quest names
-- the numbered slot before it, and those are not on any ladder any more (a house asks for the work that
-- OPENS something, and slot_02 opens nothing) -- so holding a job to a prerequisite nobody can run would
-- shut the line down at its second rung. A company is held to work it can actually go and do.
--
-- Skipped rather than blocking: a house with a capstone it cannot ask for yet asks for the next thing on
-- its line instead, and comes back to the capstone once the other house has been worked. A house that
-- fell silent until an unrelated shelf moved would read as broken. It is also what puts the capstones
-- LAST without a second sort: `quest_colosseum_champions_challenge` sorts ahead of `..._slot_01` by
-- alphabet, and is skipped until both its parents' subclass jobs are behind it.
local askedSomewhere
local function isAsked(questId)
    if not askedSomewhere then
        askedSomewhere = {}
        for vendorId in pairs(Errand.houses()) do
            for _, id in ipairs(Errand.forVendor(vendorId)) do askedSomewhere[id] = true end
        end
    end
    return askedSomewhere[questId] == true
end

function Errand.next(player, vendorId)
    local done = (player and player.completedQuests) or {}
    for _, id in ipairs(Errand.forVendor(vendorId)) do
        if not done[id] then
            local met = true
            for _, req in ipairs((Quest.defs[id] or {}).requiredQuests or {}) do
                if isAsked(req) and not done[req] then met = false end
            end
            if met then return id end
        end
    end
    return nil
end

-- The floor a company must have REACHED for that next errand to be offered -- and, once it is taken on,
-- the floor it is seated on (models/vendor_visit.lua). One number, because they are one question.
--
-- WHERE THE WORK IS FOUND CORRESPONDS TO WHAT IT UNLOCKS. An errand opens exactly one rung of its
-- house's shelf, and the ladder here is that rung's: slot 0 at the top of the descent, the house's
-- deepest slot on the deepest floor a run can seat work on. So the gear a floor buys you is the gear
-- that floor is fought at, and the shelf and the descent read as one ladder instead of two that happen
-- to run alongside each other.
--
-- THE SLOT IS `Errand.done` EXACTLY. Standing is errands run, the shelf rung is standing less the
-- opener (Quest.shelfRung), and the errand being asked for is the one after the ones already run -- so
-- the rung it will open is the count of the ones behind it. No arithmetic, and nothing to drift.
--
-- THE LADDER IS LAID BETWEEN FIRST_ASK_FLOOR AND LAST_ASK_FLOOR, whatever a house's rung count is: its
-- first asked job at floor 3, its last at floor 12, the rest spread evenly between. So the Lodge, with
-- eight rungs to fit, asks about every other floor while the Arcanum, with six, asks about every second
-- -- and the seven houses come out naturally out of step with each other rather than all wanting a job
-- on the same floor. That stagger is free here and would have to be invented on a uniform ladder.
--
-- Which is also the answer to "why not give every house the same number of rungs": the disciplines are
-- not evenly spread across the houses, the disciplines ARE the rungs, and forcing them even would mean
-- either cutting one out of the game or opening two subclasses on one job.
-- ...AND HALF THE HOUSES ASK A FLOOR LATER THAN THE OTHER HALF. Five of the seven carry six rungs, so
-- an even spread alone lands all five on the same five floors -- seven jobs on floor 3, none on floor 4,
-- which is the pile this whole re-cut exists to break up. A fixed offset by house, not a rolled one:
-- which floor the Bastion wants you on must not differ between two saves.
local houseOrder
local function stagger(vendorId)
    if not houseOrder then
        houseOrder = {}
        local sorted = {}
        for id in pairs(Errand.houses()) do sorted[#sorted + 1] = id end
        table.sort(sorted)
        for i, id in ipairs(sorted) do houseOrder[id] = (i - 1) % 2 end
    end
    return houseOrder[vendorId] or 0
end

function Errand.floorFor(player, vendorId)
    local slot = Errand.done(player, vendorId) -- the rung the errand being asked for will open
    if slot < 1 then return 1 end              -- the opener's own rung; it is found, never asked for
    local asked = Errand.tiers(vendorId) - 1   -- the opener is not asked for, so it is not on this line
    local span = Errand.LAST_ASK_FLOOR - Errand.FIRST_ASK_FLOOR
    local floor = Errand.FIRST_ASK_FLOOR + stagger(vendorId)
    if asked > 1 then floor = floor + math.floor((slot - 1) * span / (asked - 1) + 0.5) end
    return math.max(1, math.min(deepestSeatableFloor(), floor))
end

-- THE OPENER: `slot_01`, and the one piece of work that is never asked for.
--
-- Nothing about it is new -- every house's line already opens on one, authored back when the Quest Board
-- posted them. What changed is where it is met: a shut house cannot ask, so its first job is seated on a
-- floor for the player to walk into instead.
--
-- NAMED FOR THE SLOT RATHER THAN TAKEN OFF THE FRONT OF THE LINE, and that is not a nicety. Errand.forVendor
-- sorts by id, and a house whose line includes a story quest gets that quest sorted in by ALPHABET: the
-- Colosseum's door was opening on `quest_colosseum_champions_challenge` and the Crucible's on
-- `quest_alchemist_apothecary_ren`, because "champions" and "apothecary" both precede "slot". A capstone
-- bout and a companion's recruit are not the job a house posts to introduce itself, and a door gated on
-- the wrong one is a shelf the player never reaches.
--
-- Falls back to the head of the line for a house with no numbered slots at all. Nil only when there is no
-- line whatsoever -- and a door gated on an opener that does not exist is a door that never opens, which
-- is the exact failure this whole model replaced.
function Errand.opener(vendorId)
    local ids = Errand.forVendor(vendorId)
    for _, id in ipairs(ids) do
        if id:match("_slot_01$") then return id end
    end
    return ids[1]
end

-- Is this house's door open -- i.e. has its opener been run?
--
-- A house with no line has no opener, and reads OPEN rather than shut. There is no such house today;
-- the default is chosen so that authoring a shelf without a line yields a shop you can walk into rather
-- than a card that can never turn over.
function Errand.doorOpen(player, vendorId)
    local opener = Errand.opener(vendorId)
    if not opener then return true end
    return ((player and player.completedQuests) or {})[opener] == true
end

-- IS ANY HOUSE OPEN AT ALL? Returns the first vendor whose door is, or nil while every one of them is
-- still shut. Houses are asked in a fixed order (`pairs` over a registry is unspecified, and a function
-- that names a different house on two machines is a function nothing can be written against).
--
-- THE MARKETS CARD IS WHAT ASKS (data/buildings/markets.lua). The square is seven shopfronts and nothing
-- else, all seven shut on a fresh save, so a company that has opened none of them was walking into a
-- room of locked plates -- a door onto a corridor of doors. It arrives on the plaza with its first
-- tenant instead, and the six still shut in there then read as what is left to open rather than as the
-- whole of it.
function Errand.anyDoorOpen(player)
    local houses = {}
    for vendorId in pairs(Errand.houses()) do houses[#houses + 1] = vendorId end
    table.sort(houses)
    for _, vendorId in ipairs(houses) do
        if Errand.doorOpen(player, vendorId) then return vendorId end
    end
    return nil
end

-- Every house that posts a line of errands, as a set. Derived from the same walk of Quest.defs that
-- Errand.forVendor is built on rather than from a list of its own, so a house cannot exist in one and
-- not the other.
function Errand.houses()
    Errand.forVendor(nil) -- builds the cache if it is cold
    local out = {}
    for vendorId in pairs(cache or {}) do out[vendorId] = true end
    return out
end

-- Has this house got something to ask for right now?
--
-- Four gates, and each is a different question: is the door open at all (its opener), is there anything
-- left to ask (the line), is the player already carrying it, and has the company been deep enough to be
-- asked (the floor).
--
-- THE THIRD ONE IS WHAT MAKES THE ASKING FINISH. An errand is accepted by being asked, with no yes or no
-- (models/vendor_visit.lua), so a house that went on offering work already taken on would ask for the
-- same job every time its door opened -- and the red dot that means "somebody wants something" would
-- never go out, because nothing else clears that half of it (states/hub.lua's badge, Errand.doorBadge).
-- Both of those files described this behaviour before the check existed to produce it.
--
-- Taken on, NOT finished: the dot goes out when the player has the job, not when they have run it. The
-- other half of the badge covers what running it opened, and that one clears on being read.
function Errand.offered(player, vendorId, deepest)
    if not Errand.doorOpen(player, vendorId) then return nil end
    local id = Errand.next(player, vendorId)
    if not id then return nil end
    if ((player and player.errands) or {})[id] then return nil end
    if (deepest or 0) < Errand.floorFor(player, vendorId) then return nil end
    return id
end

-- WHAT A HOUSE'S DOOR HAS TO SAY, as one yes or no: it is asking for work, or it is holding wares
-- nobody has read. The red dot, in other words -- and three surfaces draw it now (the market square,
-- each shop's card on it, and the Markets card out in the city, which wears the OR of all seven), so it
-- is one function rather than the same two lines copied per board.
--
-- The two halves clear differently and both are deliberate: a request goes out when it is TAKEN ON
-- (Errand.offered stops answering), a shelf when its rows have been READ (Player.seeNew, in the shop).
function Errand.doorBadge(player, vendorId, deepest)
    if not vendorId then return false end
    if Errand.offered(player, vendorId, deepest) then return true end
    return Vendor.hasMarkedStock(vendorId, player and player.newStock)
end

-- ---------------------------------------------------------------------------
-- Taking one on
-- ---------------------------------------------------------------------------

-- Accept `errandId`, to be found on `floor`. Stored on the player as { errandId = floor } so the shop
-- can say WHICH FLOOR to look on -- an errand whose location the player has to remember is a chore
-- rather than a piece of work.
function Errand.accept(player, errandId, floor)
    if not (player and errandId) then return nil end
    player.errands = player.errands or {}
    player.errands[errandId] = floor or 1
    return floor
end

-- Every errand taken on and not yet finished, as { id, floor, def }, shallowest floor first. What the
-- shop's third tab lists and what a floor asks for when it is being built.
function Errand.open(player)
    local out = {}
    for id, floor in pairs((player and player.errands) or {}) do
        if not (player.completedQuests or {})[id] then
            out[#out + 1] = { id = id, floor = floor, def = Quest.defs[id] }
        end
    end
    -- Sorted by floor then id: `pairs` again, and a list that reorders itself between two openings of
    -- the same panel reads as a bug.
    table.sort(out, function(a, b)
        if a.floor ~= b.floor then return a.floor < b.floor end
        return a.id < b.id
    end)
    return out
end

-- The ones to seat on `floor`, as quest-shaped entries Quest.trip can build objectives from.
function Errand.onFloor(player, floor)
    local out = {}
    for _, e in ipairs(Errand.open(player)) do
        if e.floor == floor and e.def then
            local entry = {}
            for k, v in pairs(e.def) do entry[k] = v end
            entry.id = e.id
            out[#out + 1] = entry
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Meeting one on the floor
-- ---------------------------------------------------------------------------

-- WHOSE WORK IS STANDING AT THIS DEAD END, or nil when the end is not anybody's errand.
--
-- A floor's ends all look alike from the map: a marker on a dead end with a fight behind it. Two of
-- them are a house's, and until this existed the player was told so by nothing at all. The asked one
-- was at least chosen in a shop an hour ago; the OPENER was never chosen by anybody -- it is lying on
-- the floor unasked (Descent.floorObjectives), and a company that walked into it fought a siege for a
-- quartermaster they had never met and found out what it was for from a shelf that moved.
--
-- So the tile says it before the fight does (states/game.lua's askErrand), and the two kinds are told
-- apart because they are two different sentences:
--
--   asked   the house asked for this in its shop and the company came down here to find it
--   found   the house has no door yet; this is the posting that opens it
--
-- ALREADY-FINISHED READS AS NEITHER, which matters on a resumed run: a cleared cell is not re-entered,
-- but an errand can also be finished from the OTHER end (the same job seated on a floor twice over two
-- runs), and asking whether to take on work already done is a scene about nothing.
function Errand.posting(player, questId)
    if not questId then return nil end
    local def = Quest.defs[questId]
    if not (def and def.sponsor) then return nil end
    if ((player and player.completedQuests) or {})[questId] then return nil end
    local kind
    if ((player and player.errands) or {})[questId] then
        kind = "asked"
    elseif questId == Errand.opener(def.sponsor) and not Errand.doorOpen(player, def.sponsor) then
        kind = "found"
    end
    if not kind then return nil end
    return { id = questId, def = def, vendorId = def.sponsor, kind = kind }
end

-- The scene that asks. A house may answer in its own voice by authoring
-- `conversation_<vendor>_errand_<kind>`; none does today, and the two generic scenes carry all seven --
-- they name the house and read its posting out through `{house}` and `{posting}` (models/locale.lua),
-- which is the same way one "the shelf just grew" scene per shop speaks any discipline.
--
-- Generic ON PURPOSE rather than for want of authoring. The words are the same words every time because
-- the SITUATION is: a seal on a stone, a job nobody took, and a company deciding whether to spend the
-- next fight on it. What differs between two of these is the house and the work, and both of those are
-- read off the posting rather than written seven times.
Errand.SCENES = { asked = "conversation_errand_asked", found = "conversation_errand_found" }

function Errand.postingScene(posting)
    if not (posting and posting.kind) then return nil end
    local own = "conversation_" .. tostring(posting.vendorId) .. "_errand_" .. posting.kind
    if require("models.conversation").defs[own] then return own end
    return Errand.SCENES[posting.kind]
end

-- Finished. Writes the SHELF'S OWN LEDGER rather than a second one, so the stock opens by the path it
-- always did (Quest.shelfRung -> Vendor.stock), and drops the open-errand entry so the shop stops
-- listing a floor to go to.
--
-- AND DOTS WHAT IT OPENED. The shelf is diffed either side of that write and the new wares are marked
-- unseen (Quest.markOpenedStock), which is the dot the shop draws on those rows and the dot the hub
-- draws on the house's door (Vendor.hasMarkedStock). The campaign's payout seam has done this since
-- shelves started opening per quest; an errand did not, because it pays out here rather than in
-- Quest.complete -- so the one thing a house's work is FOR happened silently, in a city where the
-- player is standing in front of seven doors and cannot see which one moved.
--
-- Returns the report as a second value (nil when the errand opened nothing), so a caller with somewhere
-- to say it can name the house without diffing the shelf a third time.
function Errand.complete(player, errandId)
    if not (player and errandId) then return false end
    if (player.completedQuests or {})[errandId] then return false end
    local vendorId = (Quest.defs[errandId] or {}).sponsor
    local before = vendorId and Quest.shelf(player, vendorId)
    player.completedQuests = player.completedQuests or {}
    player.completedQuests[errandId] = true
    if player.errands then player.errands[errandId] = nil end
    return true, Quest.markOpenedStock(player, vendorId, before)
end

return Errand
