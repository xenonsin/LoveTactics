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

-- DOORS THE CITY NO LONGER HAS. See the note in Building.list: the campaign is parked, not cut, and
-- this table is the whole of the parking. Everything a retired building led to is still on disk.
Building.RETIRED = {
    quest_board = true,
}

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
-- Two kinds of gate, ANDed: `unlockPrestige` is the city growing as the company does, and
-- `unlockQuest` is a door a particular story opens -- the dueling grounds do not appear because you
-- got richer, they appear because you fought on the sand once.
--
-- `opts.district` picks which board is being laid out -- "city" (the default) or "market". The shops all
-- moved behind one Markets card and onto a board of their own; see Building.DISTRICTS.
-- `opts.includeRetired` lists the parked doors too, and exists for one caller: the specs that pin the
-- UNLOCK RULES of buildings the city no longer shows. Retiring hides a card; it does not change what
-- would open it, and those gates are still authored, still correct, and still what the campaign runs on
-- if it is ever brought back. Without this the parking would silently delete their coverage as well as
-- their card, which is the difference between parking something and losing it.
function Building.list(playerOrPrestige, opts)
    local player = type(playerOrPrestige) == "table" and playerOrPrestige or nil
    -- Quests finished, on the authored scale (Player.standing). A bare number still works for the
    -- callers that pass one directly.
    local prestige = player and require("models.player").standing(player) or playerOrPrestige or 1

    local list = {}
    for id, def in pairs(Building.defs) do
        local locked = prestige < (def.unlockPrestige or 1)
        -- RETIRED, not deleted. The Quest Board was the campaign's front door -- seven houses' work over
        -- forty days -- and the city has one door now, and it goes down (data/buildings/the_gate.lua).
        -- The board's blueprint, every quest, the calendar and the biome windows are all still on disk
        -- and untouched; what changed is that nothing shows them. Bringing the campaign back is removing
        -- this table, which is why parking it was worth doing rather than cutting it.
        local district = def.district or "city"
        if (not Building.RETIRED[id] or (opts and opts.includeRetired))
            and district == ((opts and opts.district) or "city") then
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
            local byErrand = errandVendor(id, def)
            if byErrand then
                locked = not require("models.errand").doorOpen(player, byErrand)
            elseif def.unlockQuest then
                locked = locked or not (player and Player.hasCompleted(player, def.unlockQuest))
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
                district = district, -- "city" or "market"; which board this card belongs to
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

return Building
