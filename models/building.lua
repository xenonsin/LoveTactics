-- Hub-city building logic. Blueprints live in data/buildings/<id>.lua and hold
-- a name, hotspot rect, optional panel module name, and an unlock threshold.
-- `Building.list` returns an ordered, read-only snapshot for a given prestige,
-- annotating each entry with `locked`.

local Registry = require("models.registry")
local Player = require("models.player")

local Building = {}

Building.defs = Registry.load("data/buildings", "data.buildings")

-- THE TWO BOARDS, and the authoritative copy of both. A building says which one it is on with
-- `district`; absent means the city.
--
-- THE CITY IS A PLAZA WITH THE GATE IN THE MIDDLE OF IT.
--
--     Hiring Hall        The Inn         The Markets
--     Armory          [  THE GATE  ]     The Forge
--     Cafe                               Dueling Grounds
--
-- The Gate is the only reason the city exists -- everything else on this screen is something you do
-- BEFORE going down or BECAUSE you came back up -- and a grid says the opposite: eight equal plates in
-- reading order, with the stair merely first among them. Sat in the middle and drawn larger, the board
-- states the loop instead of listing it, and the ring reads as what it is: the town that grew up around
-- a hole in the ground.
--
-- The slot under the Gate is deliberately EMPTY. It is the approach -- the avenue the plaza opens onto
-- -- and it is also the next card's home, so the city can grow once more without the layout moving.
--
-- THE MARKET IS A LATTICE, because it is a row of shopfronts and nothing on it outranks anything else.
-- Seven counters, four over a centred three. Different question from the plaza, different shape.
--
--     The Colosseum  The Bastion  The Cathedral  Hunter's Lodge
--        The Undercroft  The Arcanum  The Crucible
--
-- EVERY ONE OF THEM IS SHUT ON A FRESH SAVE, and there is no eighth card that is not. A General Store
-- stood here for a day, capped at the opening rung so it could not undercut the seven ladders around it,
-- and it was cut: the road is the shop (data/encounters/encounter_merchant.lua is reliable from floor
-- one now), and a permanent counter that sells what the floors are for selling is a counter competing
-- with the game. So the square opens empty and fills as the company works.
--
-- THE SHOPS LEFT THE CITY, which is what made room for the plaza. Fifteen doors on one screen made the
-- city a wall of cards where seven were the same kind of thing -- a shelf you browse -- and eleven of the
-- fifteen were shut on a fresh save. They live behind one Markets card now.
--
-- Keep new buildings on these coordinates; two cards on one slot is invisible in the data and obvious
-- only on the screen.
Building.GRID = {
    -- The city plaza. Three columns, symmetric about x = 640: the middle one is wider because the Gate
    -- stands in it, and its neighbours match that width so the column reads as a column.
    city = {
        cols = { 175, 490, 835 },
        rows = { 120, 300, 480 },
        w = 270, h = 130,          -- a ring card
        midW = 300,                -- ...and the middle column, which the Gate sets the width of
        gate = { x = 490, y = 280, w = 300, h = 170 }, -- centred on the middle row, and taller than it
    },
    -- The market's shopfronts: four across, then three centred under them.
    market = {
        cols = { 40, 350, 660, 970 },
        colsShort = { 195, 505, 815 }, -- the second row, three wide and centred
        rows = { 265, 413 },           -- centred in the screen: seven cards is half a board, not a top edge
        w = 270, h = 130,
    },
}

-- The boards a card can belong to. `district` on a blueprint names one; absent means "city", so a
-- building that predates the split needs no field.
Building.DISTRICTS = { city = true, market = true }

-- (Building.RETIRED held one entry -- the Quest Board -- and was the whole of "the campaign is parked,
-- not cut": its blueprint stayed on disk and one table hid its door, so bringing the board back was
-- deleting a line. It is cut now, blueprint and panel and Quest.available with it, so there is nothing
-- left to park and no door to hide. A building the city does not have is a file that is not there.)

-- WHOSE OPENING ERRAND OPENS A DOOR, or nil if none does.
--
-- `unlockErrand = true` means "my own", which is what the seven shops want: a house's first errand is
-- its own line's `slot_01`, and the building id and the vendor id are the same word. A STRING names
-- somebody else's, and exists for the one door that keeps no shelf and no line of its own -- the
-- Dueling Grounds open on the sand (data/buildings/dueling_grounds.lua).
--
-- IT WAS `unlockCircle` AND IT READ DEPTH. A house opened when its sin fell -- floors 2, 4, ... 14, in a
-- different order every run -- which meant six of the seven shelves were unreachable in any given run,
-- the disciplines behind them with them, and the only way to equip a class was to go deeper than the
-- class's gear would have got you. The errand's own header carries the rest of that argument.
local function errandVendor(id, def)
    local gate = def.unlockErrand
    if gate == true then return id end
    return gate or nil
end

-- Ordered list of buildings for a player. Each entry is a fresh copy of the def (blueprints stay
-- untouched) plus `id` and `locked`.
--
-- Accepts either the player table or, as it always did, a bare prestige number -- a building gated
-- only on prestige has nothing to ask a player about, and the callers that pass a number are not
-- wrong. A `unlockQuest` gate needs the player, so a def that names one is treated as locked when
-- all that was handed over is a number.
--
-- THE GATES, ANDed. Each one is a different kind of deed, and the reason there are several is that the
-- city grows on what the company has DONE rather than on a currency:
--
--   unlockPrestige   the campaign's ladder. Parked at 1 everywhere -- see Building.RETIRED.
--   unlockQuest      a door a particular story opens. No shipped card uses it; see tests/hub_spec.lua.
--   unlockErrand     the first piece of work a house posts on a floor (models/errand.lua).
--   unlockAnyErrand  ...or ANY house's, which is the Markets: a square of seven shut shopfronts is a
--                    door onto a corridor of doors, so it arrives with its first tenant.
--   unlockDepth      how far down this company has ever been (models/descent.lua's Descent.deepest).
--                    The Cafe at floor two, the Forge at floor four.
--   unlockWound      somebody has been carried up broken (models/wound.lua's Wound.everWounded). The
--                    Inn, whose only job is setting a bone.
--   unlockUnidentified  the company is carrying something it cannot read (models/identify.lua). The
--                    Touchstone, whose only job is reading it. The most literal of the six: the player
--                    finds the thing, cannot use it, and THEN the door is there.
--
-- WHY THE LAST THREE EXIST AT ALL, since the plaza opened whole on a fresh save until they did. Four of
-- the eight cards on the first screen of the game do nothing yet: there is no bone to set, no shelf to
-- browse, no supper worth buying for a road nobody has walked and nothing in the bag to forge. So the
-- city opens on the doors that work -- hire somebody, look at what they carry, go down -- and each of
-- the rest arrives on the expedition that gives it a job. The player learns a building at a time, and
-- learns each one at the moment it is useful.
--
-- `opts.district` picks which board is being laid out -- "city" (the default) or "market". The shops all
-- moved behind one Markets card and onto a board of their own; see Building.DISTRICTS.
-- (`opts.includeRetired` listed the parked doors too, for specs pinning the unlock rules of buildings
-- the city no longer showed. Nothing is parked any more -- the one retired door was the Quest Board and
-- it is deleted -- so the option has no doors to reveal and no caller. It is gone with the table.)
function Building.list(playerOrPrestige, opts)
    local player = type(playerOrPrestige) == "table" and playerOrPrestige or nil
    -- Quests finished, on the authored scale (Player.standing). A bare number still works for the
    -- callers that pass one directly.
    local prestige = player and require("models.player").standing(player) or playerOrPrestige or 1

    local list = {}
    for id, def in pairs(Building.defs) do
        local locked = prestige < (def.unlockPrestige or 1)
        -- The Quest Board was the campaign's front door -- seven houses' work over forty days -- and the
        -- city has one door now, and it goes down (data/buildings/the_gate.lua). It was hidden by a
        -- RETIRED table for a while and is deleted outright now, so this filter is districts alone.
        local district = def.district or "city"
        if district == ((opts and opts.district) or "city") then
            -- A HOUSE OPENS ON ITS OWN FIRST ERRAND, found on a floor. The seven shops were gated on the
            -- campaign's completed-quest count, which is parked at zero forever -- so as written they
            -- were seven cards reading "? (prestige 2)" that could never open. They were then moved onto
            -- their CIRCLE, which could at least be beaten, and that was wrong in a subtler way: it put
            -- a class's whole shelf behind fourteen floors of descent, in a different order every run,
            -- so the only way to equip a class was to go deeper than its gear would have carried you.
            --
            -- What opens a door now is the first piece of work the house ever asks for -- `slot_01`,
            -- authored years ago, seated on a floor unasked because a shut house has nowhere to ask
            -- from (models/errand.lua). One ladder per house: the opener is the door and errands two and
            -- up are the shelf, all counted in the same `completedQuests` ledger.
            --
            -- The quest gate is IGNORED for these, not satisfied: it names a campaign quest that cannot
            -- be completed, so honouring it would keep the door shut whatever the player did underground.
            local Errand = require("models.errand")
            local byErrand = errandVendor(id, def)
            if byErrand then
                locked = not Errand.doorOpen(player, byErrand)
            elseif def.unlockQuest then
                locked = locked or not (player and Player.hasCompleted(player, def.unlockQuest))
            end
            -- ...and the three gates the city itself grew on (see the header). ANDed onto whatever the
            -- gates above decided rather than replacing it, because they ask different questions: none
            -- of these three cards is a shop, so none of them is on an errand gate to be overruled.
            if def.unlockAnyErrand then
                locked = locked or not Errand.anyDoorOpen(player)
            end
            if def.unlockDepth then
                locked = locked or require("models.descent").deepest(player) < def.unlockDepth
            end
            if def.unlockWound then
                locked = locked or not require("models.wound").everWounded(player)
            end
            if def.unlockUnidentified then
                locked = locked or not require("models.identify").everFound(player)
            end
            list[#list + 1] = {
                id = id,
                name = def.name,
                order = def.order or 0,
                x = def.x,
                y = def.y,
                w = def.w,
                h = def.h,
                panel = def.panel,
                state = def.state, -- a whole screen this door opens instead of a pop-up, or nil
                vendor = def.vendor, -- vendor id for shop buildings; nil otherwise
                unlockPrestige = def.unlockPrestige or 1,
                unlockQuest = def.unlockQuest, -- quest id that opens this door, or nil
                unlockDepth = def.unlockDepth, -- floor this company must have stood on, or nil
                district = district, -- "city" or "market"; which board this card belongs to
                -- WHAT THIS DOOR IS FOR, in ONE short sentence. It is the second half of the coach
                -- bubble the city puts on a card it has just grown (states/hub.lua's doorText) -- so it
                -- is not flavour, it is the whole of what the player is told about a building before
                -- they walk into it, and it has to fit in a 240px bubble beside the card's name.
                -- Every city card carries one; tests/hub_doors_spec.lua fails one that does not, and
                -- one too long to fit.
                description = def.description,
                -- A SHUT DOOR SAYS NOTHING, and that is a decision rather than an omission. The card
                -- carried a sentence for an afternoon -- "Beat the circle of Lust", composed off
                -- whichever gate was really being asked -- and it was the right fix for a card quoting
                -- prestige, a currency the city stopped counting. It is the wrong one now. Every shut
                -- door in the market has the SAME answer (go down and walk the floors, and the work will
                -- be lying on one of them), so seven cards each naming it is seven copies of one
                -- sentence, and naming the house in it gives away the shop the card exists to withhold.
                locked = locked,
            }
        end
    end

    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

-- The prestige at which the vendor with `vendorId` first opens for business -- i.e. the
-- unlock threshold of the building that houses it. A quest hides its sponsor's line until
-- that shop exists in the hub (see models/quest.lua); showing a quest for a vendor the
-- player cannot yet visit only advertises a locked door. A vendor with no building, or a
-- nil id, defaults to 1 (always open).
function Building.vendorUnlockPrestige(vendorId)
    if not vendorId then return 1 end
    for _, def in pairs(Building.defs) do
        if def.vendor == vendorId then
            return def.unlockPrestige or 1
        end
    end
    return 1
end

-- ---------------------------------------------------------------------------
-- Doors the city has grown: the ledger, and what is owed an announcement
-- ---------------------------------------------------------------------------
--
-- THE PROBLEM A GROWING CITY HAS. Six of the nine cards on the plaza are shut on a fresh save and each
-- opens on a deed done underground (see the gate table above) -- so the player comes up from a floor,
-- and a building that was three question marks is suddenly a name. Nothing says it happened, nothing
-- says what the room is for, and the one moment the door is interesting is the moment it appears. A
-- card that quietly stops being locked is a feature delivered by not being mentioned.
--
-- So the city COACHES a door it has just grown, in exactly the way it coaches the hall and the stair on
-- the first visit (states/hub.lua's INTRO_STAGES): a bubble pinned to the card, carrying the card's name
-- and the blueprint's own `description` of what the room is for, and while it is up that card is the
-- only one that opens. A room explained and then walked into is learned; a room explained is read.
--
-- A POP-UP DID THIS FOR AN AFTERNOON and was cut. The city already has a grammar for "press this, and
-- here is why", and a modal in front of it covers the plate it is naming, has to be dismissed before the
-- thing it is pointing at can be reached, and makes a new counter a bigger event than the stair the
-- whole game is about. The sentence it carried is in the bubble now.
--
-- `player.seenDoors` is the whole of the memory: building id -> true, for every door the player has
-- been shown. It is NIL rather than empty until the city is first looked at, and that distinction is
-- load-bearing -- an empty table would be indistinguishable from a save written before this existed,
-- and every such save would come back to a city announcing all three of its opening doors as news.
-- Building.seedSeen is what flips nil to a real ledger, and it can never leave it empty (the plaza
-- always has the stair, the hall and the Armory open).

-- Has the player looked at the city at all? False only before Building.seedSeen has ever run, which is
-- the first hub entry of a new game -- and every save written before the ledger existed.
function Building.seeded(player)
    return type(player and player.seenDoors) == "table"
end

-- Has this door already been announced (or been open since before the ledger started)?
function Building.seenDoor(player, id)
    return ((player and player.seenDoors) or {})[id] == true
end

-- Record that the player has been shown this door, so it is never announced again. Called when the
-- coached card is actually walked into -- by the deed, not by the bubble being read, for the reason the
-- first visit's hire stage is: a lesson satisfied by reading a card teaches reading cards.
function Building.markSeen(player, id)
    if not (player and id) then return end
    player.seenDoors = player.seenDoors or {}
    player.seenDoors[id] = true
end

-- Record every door the city currently has open, announcing none of them. The first look at the city,
-- and the only way the ledger is created.
--
-- What it buys is that nothing already standing is ever news. On a new game that is the three cards the
-- plaza opens with -- the stair, the hall and the Armory -- which are the first visit's own business
-- (states/hub.lua's INTRO_STAGES coaches two of them, and a forced tour of the third on top of the
-- sponsor's scene would be a fourth thing happening before the player has pressed anything). On a save
-- written before any of this existed it is however much of the city that company had already earned,
-- which is exactly right: they have been using those rooms for hours.
function Building.seedSeen(player)
    if not player then return end
    player.seenDoors = player.seenDoors or {}
    for _, b in ipairs(Building.list(player, { district = "city" })) do
        if not b.locked then player.seenDoors[b.id] = true end
    end
end

-- The doors the city has grown that the player has not been shown yet, in board order (the Gate first,
-- the Touchstone last) so a morning that opened two of them announces them in the order they are read.
--
-- EMPTY WHILE UNSEEDED, deliberately. An unseeded ledger means the player has not looked at the city,
-- and nothing that was already there when they arrived is news -- so the safe answer to "what is new"
-- for somebody who has seen nothing is "nothing", and the caller seeds first (states/hub.lua).
function Building.unannounced(player)
    if not Building.seeded(player) then return {} end
    local new = {}
    for _, b in ipairs(Building.list(player, { district = "city" })) do
        if not b.locked and not Building.seenDoor(player, b.id) then new[#new + 1] = b end
    end
    return new
end

return Building
