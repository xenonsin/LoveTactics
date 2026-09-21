-- Hub-city building logic. Blueprints live in data/buildings/<id>.lua and hold
-- a name, hotspot rect, optional panel module name, and an unlock threshold.
-- `Building.list` returns an ordered, read-only snapshot for a given prestige,
-- annotating each entry with `locked`.

local Registry = require("models.registry")
local Player = require("models.player")
local Scale = require("scale") -- authored 1280x720 door rects -> the live space (see below)

local Building = {}

Building.defs = Registry.load("data/buildings", "data.buildings")

-- THE ONE BOARD, and the authoritative copy of it. There were two -- the plaza, and a square of seven
-- shopfronts behind one of its cards -- and the fold put them back together (models/counter.lua).
--
-- THE CITY IS A PLAZA WITH THE RIFT IN THE MIDDLE OF IT.
--
--     The Colosseum    The Cathedral     The Bastion
--     Armory          [   THE RIFT   ]   Hunter's Lodge
--     The Undercroft   The Crucible      The Arcanum
--
-- NINE CARDS, NINE SLOTS, and the fit is exact rather than lucky: the lattice has always been three by
-- three with the stair taking the taller middle slot, which leaves eight in the ring -- the Armory, and
-- one per house. Every other room the city had is a LINE on one of those seven desks.
--
-- The Gate is the only reason the city exists -- everything else on this screen is something you do
-- BEFORE going down or BECAUSE you came back up -- and a grid says the opposite: eight equal plates in
-- reading order, with the stair merely first among them. Sat in the middle and drawn larger, the board
-- states the loop instead of listing it, and the ring reads as what it is: the town that grew up around
-- a hole in the ground.
--
-- SEVEN MORE CARDS ON THIS BOARD WOULD ONCE HAVE BEEN A WALL OF PLATES, and that reading is what put
-- the class shelves on a square of their own twice. It stopped being true when the rooms folded into
-- them: a house is no longer "a shelf you browse" but a shopkeeper with a desk, and what is behind each
-- desk is different at every door -- a bone set, a supper, a bench, a reading, a match, the town's own
-- counter. Seven of the same thing is a wall; seven of seven things is a city.
--
-- SO THE SECOND BOARD IS GONE, and with it the card that opened it and the state that drew it. The
-- growth the city had -- a plate arriving on the morning it has a job -- did not go anywhere: it moved
-- inside the doors, where a ROOM arrives on the trip that gives it a job (models/offer.lua). A house's
-- plate appears when the first of its rooms does.
--
-- Keep new buildings on these coordinates, and keep one card to a slot. Two plates on one rect is
-- invisible in the data and obvious only on the screen -- and worse than obvious when one of the two
-- is SHUT, because the locked plate draws last and its "???" prints over the open card's name
-- (ui/building_map.lua). The Ward shipped on the Houses' slot and read exactly that way.
-- tests/hub_spec.lua pins it. The ring is FULL at nine: a tenth card needs a room on a desk, not a
-- slot, and that is now the cheap move rather than the expensive one.
--
-- Keep new buildings on these coordinates, and keep one card to a slot. Two plates on one rect is
-- invisible in the data and obvious only on the screen -- and worse than obvious when one of the two
-- is SHUT, because the locked plate draws last and its "???" prints over the open card's name
-- (ui/building_map.lua). The Ward shipped on the Houses' slot and read exactly that way.
-- tests/hub_spec.lua pins it.
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
    -- (GRID.houses held the second board -- four shopfronts over a centred three -- and is gone with it.
    -- The seven stand in the ring above, one per slot.)
}

-- (BUILDING.DISTRICTS IS GONE, AND SO IS THE SECOND BOARD.) A card used to name the board it stood on
-- with `district`, because the seven class shelves lived behind one plaza card and on a square of their
-- own. They are back on the plaza -- the rooms folded into them, so the seven are no longer seven of the
-- same thing -- and nine cards fit the lattice exactly: the Rift in the middle, the Armory, and the
-- seven houses around them. One board, so nothing has to say which.

-- THE CLASS LEVEL A HOUSE'S SHELF WAITS FOR, or nil for a card that keeps no shelf.
--
-- It used to be `unlockClassLevel` on the blueprint and it used to gate the DOOR. It gates the shelf
-- alone now: a house is a shopkeeper with a desk, and the shelf is one line on it (models/offer.lua).
-- The Cathedral is the case that forced the move -- Rowan is carried up broken at the end of Act 0, so a
-- player needs that door on the first morning, and there is no priest in the world yet. A door gated on
-- its shelf would have put the only bone-setting in the game behind a class nobody has.
--
-- Read off the shelf offer's own gate rather than a second field, so the number the card quotes and the
-- number the desk enforces cannot drift apart.
local function shelfNeed(def)
    for _, offer in ipairs(def.offers or {}) do
        if offer.gate and offer.gate.classLevel then return offer.gate.classLevel end
    end
    return nil
end

-- THE HOUSE THAT TEACHES A CLASS -- its card in the square, whether its door is open for this player,
-- and the class level it is waiting for. The Roll sends a body to its trainer from the class it is
-- reading (ui/class_editor.lua), and that button needs all three: where to go, whether it may, and what
-- to say when it may not.
--
-- Asked of the CLASS and answered through the vendor: a shelf belongs to exactly one class
-- (data/vendors/<id>.lua) and the card names the shelf, so the class is never written on the building.
-- Nil when the class has no house, which is every subclass and crossing -- ask this about the ROOT the
-- class hangs off, not about the class itself.
--
-- `open` IS ABOUT THE SHELF, NOT THE DOOR, and since the fold those are two questions. The door is open
-- as soon as ANY room behind it is (models/offer.lua's Offer.any) -- the Cathedral stands open on the
-- first morning for its mending -- while the shelf waits for the class. What the trainer button needs is
-- the shelf's answer: it is offering to walk a body to the counter that teaches its class, and that
-- counter is the line the class level buys.
function Building.houseForClass(class, player)
    if not class then return nil end
    local vendorId = require("models.vendor").forClass(class)
    if not vendorId then return nil end
    for id, def in pairs(Building.defs) do
        if def.vendor == vendorId then
            local need = shelfNeed(def)
            return {
                id = id,
                name = def.name,
                class = class,
                need = need,
                open = require("models.offer").open(player, need and { classLevel = need } or nil,
                                                   def.vendor),
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
--   unlockExpeditions  how many times this company has been out and finished what it went for, by
--                    EITHER door (Player.expeditionsOut -- bounties finished, or floors descended).
--                    The Cafe at two, the Forge at four. It was `unlockDepth` and read floors alone;
--                    the stair stopped being the only way out of the city, so the noun had drifted.
--   unlockWound      somebody has been carried up broken. It opened the INN, which was deleted on
--                    2026-09-02 along with the toll it charged, and this gate went with it. Both are
--                    back as of 2026-09-16, pointed at the WARD (data/buildings/the_ward.lua) -- and the
--                    difference is the whole reason it is legal this time: the Inn charged at the door,
--                    so you paid to be treated at all, where the Ward's rest is free forever and the
--                    gold buys only speed. See models/wound.lua's ward block for the full argument and
--                    for the two earlier passes it is not repeating.
--
--                    THE GATE IS THE LESSON. The Ward is the one door in the city whose job a player
--                    cannot understand until it is needed, so it arrives on the beat that teaches it:
--                    Rowan is felled by the Demon Champion at the end of Act 0, and the wound she
--                    carries into town is what puts this card on the plaza.
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
-- (`opts.district` picked which of two boards was being laid out. There is one board -- see the header
-- -- so it has nothing left to choose between and is gone with the square it named. `opts` survives for
-- the next option that needs it.)
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
        -- RETIRED table for a while and is deleted outright now, and the district filter that stood here
        -- after it went with the second board. Nothing filters; every card in the registry is on the one
        -- plaza.
        do
            -- A DOOR IS OPEN WHEN ANY ROOM BEHIND IT IS (models/offer.lua).
            --
            -- This is the gate the fold turned every house's `unlockClassLevel` into, and the reason it
            -- had to change is the Cathedral: Rowan is carried up broken at the end of Act 0, the only
            -- bone-setting in the game is a line on that desk, and on the first morning there is no
            -- priest in the world. A door gated on its shelf would have hidden the room the player was
            -- holding the problem for.
            --
            -- SO THE CITY STILL GROWS ON EXACTLY THE SAME SCHEDULE, it just grows INSIDE doors. Each
            -- room kept the gate its card had -- the mending on the first body carried up broken, the
            -- supper on the second floor, the bench on the fourth, the reading on the first thing
            -- nobody can read -- and a house's plate appears the morning the first of its rooms does.
            -- What arrives is a line on a desk rather than a plate on the board.
            --
            -- A building with no offers answers open, so the Armory and the Rift are unaffected: they
            -- are doors onto one thing each and keep their own gates below.
            locked = locked or not require("models.offer").any(player, def)
            if def.unlockQuest then
                locked = locked or not (player and Player.hasCompleted(player, def.unlockQuest))
            end
            -- ...and the two gates the city itself grew on (see the header).
            if def.unlockExpeditions then
                locked = locked or Player.expeditionsOut(player) < def.unlockExpeditions
            end
            if def.unlockUnidentified then
                locked = locked or not require("models.identify").everFound(player)
            end
            -- ...and the door that opens the first time somebody is carried up broken. The mark is
            -- one-way and never cleared -- not by setting the bone, not by walking home -- so the Ward
            -- stays on the plaza once it has arrived (models/wound.lua's Wound.everWounded).
            if def.unlockWound then
                locked = locked or not require("models.wound").everWounded(player)
            end
            -- The ONLY place a hand-authored 1280x720 rect crosses into the live space. Every
            -- building in data/buildings positions its door by eye against the city art, and on a
            -- handheld that space is shorter and wider (scale.lua) -- so the rect has to travel with
            -- it. Both axes scale independently, matching how states/hub.lua stretches the city
            -- picture itself: a hotspot must distort exactly as much as the door it names.
            local bx, by, bw, bh = Scale.fromAuthored(def.x, def.y, def.w, def.h)
            list[#list + 1] = {
                id = id,
                name = def.name,
                order = def.order or 0,
                x = bx,
                y = by,
                w = bw,
                h = bh,
                panel = def.panel,
                state = def.state, -- a whole screen this door opens instead of a pop-up, or nil
                vendor = def.vendor, -- vendor id for shop buildings; nil otherwise
                -- A ONE-TIME SCENE THIS ROOM PLAYS THE FIRST TIME IT IS WALKED INTO, and optionally the
                -- companion it hands over -- which is how the Ward introduces Xin. A shop does this
                -- through models/vendor_visit.lua, keyed on its vendor id; a room with no shelf has no
                -- vendor to key on, and inventing one so a door can say a sentence would put an empty
                -- counter in the data to carry a scene. `Building.seenDoor` is already the ledger of
                -- which rooms have been walked into, so the flag this needs exists.
                intro = def.intro,
                grants = def.grants,
                -- ...and the room whose CLOSE plays it, for a house whose scene belongs on the far
                -- side of a press rather than in the doorway (models/counter.lua's introAfter).
                introAfter = def.introAfter,
                unlockPrestige = def.unlockPrestige or 1,
                unlockQuest = def.unlockQuest, -- quest id that opens this door, or nil
                unlockDepth = def.unlockDepth, -- floor this company must have stood on, or nil
                -- THE DESK AND THE ROOMS BEHIND IT (models/counter.lua, models/offer.lua). `counter` is
                -- the scene this house plays on the way in, ending on the desk that names its rooms;
                -- `offers` is what those rooms are and what each one waits for. Carried onto the entry
                -- so the city can ask a card what it holds without re-reading the blueprint.
                counter = def.counter,
                offers = def.offers,
                -- The class level this house's SHELF waits for, or nil -- so a board can say what a card
                -- is still holding back without re-reading the offer list. Not a door gate any more:
                -- see the gate block above and shelfNeed.
                unlockClassLevel = shelfNeed(def),
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
--
-- Returns true only when it actually flipped, so a caller persists on the transition rather than on
-- every door it opens (Player.seeNew draws the same line for the item dots).
function Building.markSeen(player, id)
    if not (player and id) then return false end
    player.seenDoors = player.seenDoors or {}
    if player.seenDoors[id] then return false end
    player.seenDoors[id] = true
    return true
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
--
-- BOTH BOARDS, because both draw off this ledger now. The plaza spends it on the coach bubble; the
-- square spends it on the red dot on a shelf that opened while nobody was standing there
-- (states/houses.lua). One ledger and not two: building ids are unique across the registry, and a
-- second copy of "which doors has this player been shown" is the copy that goes stale.
function Building.seedSeen(player)
    if not player then return end
    player.seenDoors = player.seenDoors or {}
    for _, b in ipairs(Building.list(player)) do
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
    for _, b in ipairs(Building.list(player)) do
        if not b.locked and not Building.seenDoor(player, b.id) then new[#new + 1] = b end
    end
    return new
end

return Building
