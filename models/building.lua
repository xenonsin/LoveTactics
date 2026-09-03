-- Hub-city building logic. Blueprints live in data/buildings/<id>.lua and hold
-- a name, hotspot rect, optional panel module name, and an unlock threshold.
-- `Building.list` returns an ordered, read-only snapshot for a given prestige,
-- annotating each entry with `locked`.

local Registry = require("models.registry")
local Player = require("models.player")

local Building = {}

Building.defs = Registry.load("data/buildings", "data.buildings")

-- THE TWO BOARDS, and the authoritative copy of both. A building says which one it is on with
-- `district`; absent means the city. The second board is THE HOUSES -- the seven class shelves, back
-- from the dead and gated on the ladder rather than on a story (see the district's own note below).
--
-- THE CITY IS A PLAZA WITH THE GATE IN THE MIDDLE OF IT.
--
--     The Houses         --              The Market
--     Armory          [  THE GATE  ]     The Forge
--     Cafe             Touchstone        Dueling Grounds
--
-- The Gate is the only reason the city exists -- everything else on this screen is something you do
-- BEFORE going down or BECAUSE you came back up -- and a grid says the opposite: eight equal plates in
-- reading order, with the stair merely first among them. Sat in the middle and drawn larger, the board
-- states the loop instead of listing it, and the ring reads as what it is: the town that grew up around
-- a hole in the ground.
--
-- The slot over the Gate is deliberately EMPTY. It is the approach -- the avenue the plaza opens onto
-- -- and it is also the next card's home, so the city can grow once more without the layout moving.
--
-- THE HOUSES: the second board, and the seven class shelves standing round it. Four over a centred
-- three. Different question from the plaza, different shape.
--
--     The Colosseum  The Bastion  The Cathedral  Hunter's Lodge
--        The Undercroft  The Arcanum  The Crucible
--
-- EACH ONE OPENS ON ITS CLASS, at level 1 in any body on the roster (`unlockClassLevel`). That is the
-- gate the seven were always missing. They were shut behind quest counts that never moved, then behind
-- a circle of the descent, then deleted outright when the houses became classes -- and deleting them
-- left the ladder paying out in nothing but a wider pool for the Market's daily roll. A class level is
-- what a body EARNS by playing that class, so the door opens for the work that will shop through it,
-- and the seven arrive one at a time in whatever order this company actually plays.
--
-- WHY A BOARD OF ITS OWN AND NOT SEVEN MORE CARDS ON THE PLAZA. The plaza is nine slots and holds
-- seven; seven more would be a wall of plates where over half were the same kind of thing -- a shelf
-- you browse -- which is the reading that moved them off it the first time. One card, and behind it
-- the square.
--
-- THE SQUARE IS NEVER AN EMPTY ROOM: its card in the city waits for its first tenant
-- (`unlockAnyHouse`), so a company that has climbed nothing is not pressing a door onto seven locked
-- plates. The six still shut then read as what is LEFT rather than as the whole of what the city sells.
--
-- THE MARKET STAYS ON THE PLAZA, and the two are not the same shop. The Market is the town's own
-- counter -- plain kit and three rolled rows a day, open on the first morning, any class
-- (models/market.lua). A house is one class's whole ladder, never rolled, and it grows as that class
-- does. Day-one shopping and earned shopping, one card each.
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
    -- The houses' shopfronts: four across, then three centred under them.
    houses = {
        cols = { 40, 350, 660, 970 },
        colsShort = { 195, 505, 815 }, -- the second row, three wide and centred
        rows = { 265, 413 },           -- centred in the screen: seven cards is half a board, not a top edge
        w = 270, h = 130,
    },
}

-- The boards a card can belong to. `district` on a blueprint names one; absent means "city", so a
-- building that predates the split needs no field.
Building.DISTRICTS = { city = true, houses = true }

-- Is this house's class climbed far enough to open its door? The class is read off the VENDOR the card
-- names (data/vendors/<id>.lua's `class`) rather than repeated on the building, because a shelf already
-- belongs to exactly one class and two copies of that fact is one of them going stale.
--
-- A bare prestige number instead of a player answers "shut", as every player-needing gate here does:
-- the callers that pass a number are asking about a door that has nothing to ask a player.
local function houseOpen(def, player)
    local need = def.unlockClassLevel
    if not need then return true end
    local vdef = def.vendor and require("models.vendor").defs[def.vendor]
    local class = vdef and vdef.class
    if not (class and player) then return false end
    return require("models.class").rosterLevel(player, class) >= need
end

-- Has any of the seven opened? What the card out in the city waits for.
function Building.anyHouseOpen(player)
    for _, def in pairs(Building.defs) do
        if def.unlockClassLevel and houseOpen(def, player) then return true end
    end
    return false
end

-- THE HOUSE THAT TEACHES A CLASS -- its card in the square, whether its door is open for this player,
-- and the class level it is waiting for. The Roll sends a body to its trainer from the class it is
-- reading (ui/class_editor.lua), and that button needs all three: where to go, whether it may, and what
-- to say when it may not.
--
-- Asked of the CLASS and answered through the vendor, the same hop houseOpen takes: a shelf belongs to
-- exactly one class (data/vendors/<id>.lua) and the card names the shelf, so the class is never written
-- on the building. Nil when the class has no house, which is every subclass and crossing -- ask this
-- about the ROOT the class hangs off, not about the class itself.
function Building.houseForClass(class, player)
    if not class then return nil end
    local vendorId = require("models.vendor").forClass(class)
    if not vendorId then return nil end
    for id, def in pairs(Building.defs) do
        if def.vendor == vendorId then
            return {
                id = id,
                name = def.name,
                class = class,
                need = def.unlockClassLevel,
                open = houseOpen(def, player),
            }
        end
    end
    return nil
end

-- (Building.RETIRED held one entry -- the Quest Board -- and was the whole of "the campaign is parked,
-- not cut": its blueprint stayed on disk and one table hid its door, so bringing the board back was
-- deleting a line. It is cut now, blueprint and panel and Quest.available with it, so there is nothing
-- left to park and no door to hide. A building the city does not have is a file that is not there.)

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
--   unlockDepth      how far down this company has ever been (models/descent.lua's Descent.deepest).
--                    The Cafe at floor two, the Forge at floor four.
--   (unlockWound     somebody has been carried up broken. It opened the Inn, whose only job was setting
--                    a bone. Both are gone: a wound is a condition of the expedition now and the surface
--                    ends it for free (models/wound.lua), so there is no bone left to sell the setting
--                    of. The gate is deleted rather than parked -- nothing authors it.)
--   unlockUnidentified  the company is carrying something it cannot read (models/identify.lua). The
--                    Touchstone, whose only job is reading it. The most literal of the six: the player
--                    finds the thing, cannot use it, and THEN the door is there.
--
-- WHY THE LAST TWO EXIST AT ALL, since the plaza opened whole on a fresh save until they did. Several
-- of the cards on the first screen of the game do nothing yet: there is no shelf to browse, no supper
-- worth buying for a road nobody has walked and nothing in the bag to forge. So the
-- city opens on the doors that work -- hire somebody, look at what they carry, go down -- and each of
-- the rest arrives on the expedition that gives it a job. The player learns a building at a time, and
-- learns each one at the moment it is useful.
--
-- `opts.district` picks which board is being laid out -- "city" (the default) or "houses". The class
-- shelves stand behind one card and on a board of their own; see Building.DISTRICTS.
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
            -- THE HOUSES' GATE, and the fourth thing tried in that slot. It was the campaign's
            -- completed-quest count (which sat at zero forever, so the seven shops read "? (prestige 2)"
            -- and could never open), then the descent's own circles (which put a class's whole shelf
            -- behind fourteen floors in a different order every run, so the only way to equip a class
            -- was to go deeper than its gear would have carried you), then nothing at all -- the doors
            -- were deleted when the houses became classes.
            --
            -- It is the CLASS LEVEL now, and that is the shape the first three were reaching for: a
            -- class is something a body climbs (Class.classLevel), so the deed that opens a shelf is the
            -- deed that will shop at it. Level 1 in any body on the roster -- the company reading, as
            -- every company-facing question about the ladder takes (Class.rosterLevel) -- because one
            -- body committing is what a house is for and four bodies dabbling is not.
            if def.unlockClassLevel then
                locked = locked or not houseOpen(def, player)
            end
            -- ...and the card in the city that all seven stand behind, which arrives with whichever of
            -- them opens first: a door onto a square of locked plates teaches one sentence ("come back
            -- when you have climbed something") that the card says better by not being there.
            if def.unlockAnyHouse then
                locked = locked or not Building.anyHouseOpen(player)
            end
            if def.unlockQuest then
                locked = locked or not (player and Player.hasCompleted(player, def.unlockQuest))
            end
            -- ...and the two gates the city itself grew on (see the header).
            if def.unlockDepth then
                locked = locked or require("models.descent").deepest(player) < def.unlockDepth
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
                district = district, -- "city" or "houses"; which board this card belongs to
                -- The class level this shelf waits for, or nil. Carried onto the entry so a board can
                -- say what a shut plate is waiting for without re-reading the blueprint.
                unlockClassLevel = def.unlockClassLevel,
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
                -- door in the square has the SAME answer (climb the class, and its shelf is here), so
                -- seven cards each naming it is seven copies of one sentence -- and the square's own
                -- subtitle says it once, where it is read before any of the plates are.
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
