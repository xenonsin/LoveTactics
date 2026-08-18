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

local Errand = {}

-- HOW DEEP THE COMPANY MUST HAVE GONE for a house to ask for its Nth errand.
--
-- One rung per two floors, so a fifteen-floor descent asks for about seven errands from any one house
-- across its whole length -- which is roughly the shelf depth those lines were authored to open. It is
-- deliberately NOT one per floor: a house that had a new job every time you came up would turn the city
-- into a queue of chores, and the shelf would outrun what the floors are handing out anyway.
--
-- The door is the gate above this one and it is separate: a house whose opener has not been run asks
-- for nothing at all, because there is nowhere to ask (models/building.lua).
Errand.FLOORS_PER_RUNG = 2

-- The ordered list of a house's errands, shallowest first. Sorted by ID because the slot number IS the
-- order -- `quest_bastion_slot_01` before `_02` -- and `pairs` over the registry is unspecified, so a
-- house would otherwise ask for its seventh errand first on some machines and not others.
local cache
function Errand.forVendor(vendorId)
    if not cache then
        cache = {}
        for id, def in pairs(Quest.defs) do
            if def.sponsor and def.map and def.map.objective then
                cache[def.sponsor] = cache[def.sponsor] or {}
                table.insert(cache[def.sponsor], id)
            end
        end
        for _, ids in pairs(cache) do table.sort(ids) end
    end
    return cache[vendorId] or {}
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
function Errand.next(player, vendorId)
    local done = (player and player.completedQuests) or {}
    for _, id in ipairs(Errand.forVendor(vendorId)) do
        if not done[id] then return id end
    end
    return nil
end

-- The floor a company must have REACHED for that next errand to be offered.
function Errand.floorFor(player, vendorId)
    return (Errand.done(player, vendorId) + 1) * Errand.FLOORS_PER_RUNG
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

-- Has this house got something to ask for right now?
--
-- Three gates, and each is a different question: is the door open at all (its opener), is there anything
-- left to ask (the line), and has the company been deep enough to be asked (the floor).
function Errand.offered(player, vendorId, deepest)
    if not Errand.doorOpen(player, vendorId) then return nil end
    local id = Errand.next(player, vendorId)
    if not id then return nil end
    if (deepest or 0) < Errand.floorFor(player, vendorId) then return nil end
    return id
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

-- Finished. Writes the SHELF'S OWN LEDGER rather than a second one, so the stock opens by the path it
-- always did (Quest.sponsorProgress -> Vendor.stock), and drops the open-errand entry so the shop stops
-- listing a floor to go to.
function Errand.complete(player, errandId)
    if not (player and errandId) then return false end
    if (player.completedQuests or {})[errandId] then return false end
    player.completedQuests = player.completedQuests or {}
    player.completedQuests[errandId] = true
    if player.errands then player.errands[errandId] = nil end
    return true
end

return Errand
