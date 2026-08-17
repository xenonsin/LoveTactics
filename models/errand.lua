-- ERRANDS: the small pieces of work a house asks for, and the second half of what opens its shelf.
--
-- A house opens its DOOR when its circle falls (models/building.lua's `unlockCircle`). What it does not
-- do is hand over its whole catalogue for having beaten a general -- the shelf still climbs a rung at a
-- time, and each rung is bought by doing something for the house. So a vendor's stock is gated twice:
-- by the FLOOR you have reached, and by the errands you have run for them.
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
-- The circle itself is the first gate and it is separate: a house that has not been beaten asks for
-- nothing at all, because its door is shut (models/building.lua).
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
function Errand.next(player, vendorId)
    local ids = Errand.forVendor(vendorId)
    return ids[Errand.done(player, vendorId) + 1]
end

-- The floor a company must have REACHED for that next errand to be offered.
function Errand.floorFor(player, vendorId)
    return (Errand.done(player, vendorId) + 1) * Errand.FLOORS_PER_RUNG
end

-- Has this house got something to ask for right now?
--
-- Three gates, and each is a different question: is the door open at all (its circle), is there anything
-- left to ask (the line), and has the company been deep enough to be asked (the floor).
function Errand.offered(player, vendorId, deepest)
    if ((player and player.standing or {})[vendorId] or 0) <= 0 then return nil end
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
