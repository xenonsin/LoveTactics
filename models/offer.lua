-- WHAT A COUNTER OFFERS, AND WHETHER EACH OFFER IS OPEN YET.
--
-- The city used to grow one CARD at a time: a plate appeared on the plaza on the expedition that gave it
-- a job, wearing its own sentence about what the room was for. Sixteen cards across two boards later,
-- over half of them were the same kind of thing -- a shelf you browse -- and the plaza had run out of
-- slots twice. So the shelves and the rooms were folded together: seven houses, each a shopkeeper with a
-- desk, and every room the city had is a LINE on one of those desks (models/counter.lua).
--
-- THE GROWTH DID NOT GO ANYWHERE, IT MOVED INSIDE. This module is what makes that true. An offer is one
-- room behind one door, and it carries the same gate the card used to -- so the Inn's mending still
-- arrives the first time somebody is carried up broken, and the bench still waits for the fourth floor.
-- What changed is that the arrival is a line appearing on a desk rather than a plate appearing on a
-- board.
--
--   * a DOOR is open when ANY offer behind it is (Offer.any -- models/building.lua's door gate)
--   * a DESK LINE shows when ITS offer is (Offer.openSet -> the `offer` predicate in a scene's `when`)
--
-- ONE FUNCTION ANSWERS BOTH, and that is the whole point of the file. Two readers asking the same
-- question -- "is this room open" -- with two implementations is how a door ends up standing on a room
-- nobody can reach, or a desk line offering a bench that is not built yet. The card-era gates had
-- exactly one reader (Building.list) and could afford to live there; these have two.
--
-- Pure model: no love.graphics, no state switching, safe under the headless runner.

local Offer = {}

-- The gate vocabulary, deliberately the SAME WORDS models/building.lua's unlock keys use, minus the
-- `unlock` prefix that only made sense on a card. A gate is a table; every key in it must hold, so
-- `{ expeditions = 2, wound = true }` ANDs. An offer with no gate is open always, which is the common
-- case -- most rooms behind a door are simply the door's own business.
--
-- (`classLevel` stood here and is GONE WITH THE SHELF GATE. It read the roster's best level in the
-- house's own class, and its only readers were the seven shelves -- one apiece, all at 1. That gate made
-- sense while it also hid the CARD: under the card era a shut shelf hid the whole shopfront, so "you
-- have not played a rogue" and "there is no Undercroft" were one fact. The fold put the doors on the
-- plaza for other rooms' sake, and the gate quietly became "walk through a shopfront and be offered no
-- shop". A class level buys the shelf's DEPTH now and nothing else -- Quest.shelfRung, where level 0 is
-- rung 0 and the bottom band a gate at 1 had made unreachable. `vendorId` below is what it needed and
-- is kept, because a house gate that has to hop through the vendor is the shape any successor takes.)
local GATES = {}

-- HOW MANY TIMES THIS COMPANY HAS GONE DOWN, which is the clock the CITY grows on.
--
-- Not `expeditions`, and the difference is the whole of why this gate exists. `Player.expeditionsOut`
-- is `max(bounties, deepest)` -- how DEEP you have been -- and depth is the one axis a player can jump
-- four notches of in a single trip, or never advance at all. Measured: a company that pushed to floor
-- four on its first descent came home to FOUR new doors at once and then three empty homecomings, while
-- a company that farmed floor one had its city frozen after the first.
--
-- Trips home are monotonic and arrive one at a time, so one room per homecoming falls out of the unit
-- rather than out of a queue or a cap. And it prices the right deed: this mode is built on surfacing
-- (docs), so the town growing when you COME BACK reinforces the loop instead of rewarding the one
-- behaviour -- diving past everything -- that the loop is trying not to be.
--
-- WHAT DEPTH STILL BUYS is what is BEHIND the doors: shelf rungs, stock tiers, drop tiers. Trips pace
-- the city; depth paces the shelves. Neither does the other's job.
GATES.trips = function(player, need)
    return require("models.player").tripsHome(player) >= need
end

-- Kept for a room whose arrival really is about depth rather than about coming home.
GATES.expeditions = function(player, need)
    return require("models.player").expeditionsOut(player) >= need
end

-- A boolean gate, written out longhand ON PURPOSE. The obvious `want and is or not is` is wrong in Lua
-- whenever `is` is false -- it falls through to the `or` arm and answers TRUE -- so both gates below read
-- as open on a fresh save, and the Cathedral and the Crucible stood on the plaza on the first morning
-- offering rooms for a wound nobody had and a find nobody was carrying. The suite caught it; the idiom
-- is the trap, so neither of these gets to use it.
local function is(value, want)
    local held = value and true or false
    return held == (want and true or false)
end

-- Somebody has been carried up broken. One-way and never cleared -- not by setting the bone, not by
-- walking home -- so the mending line stays on the desk once it has arrived, exactly as the card did.
GATES.wound = function(player, want)
    return is(require("models.wound").everWounded(player), want)
end

-- The company is carrying something it cannot read. The most literal gate in the game: the player finds
-- the thing, cannot use it, and THEN the line is there.
GATES.unidentified = function(player, want)
    return is(require("models.identify").everFound(player), want)
end

-- Something this company owns has been hexed (models/curse.lua). The same one-way shape `wound` above
-- has, and for a sharper version of the same reason: a curse can be LIFTED, so a gate that read a live
-- count would put the rite on the desk, have the player use it, and take the room away in the same
-- visit -- removing the door at the exact moment they learned what it was for. Once a company has met a
-- curse, the Cathedral goes on offering to lift them.
-- `noticed` rather than `everCursed`, and the difference is a room that would otherwise never open:
-- most vectors cannot reach a player to stamp the mark (Combat.curseItem is handed a board, and a board
-- does not know whose company it is fighting for), so the gate reads the live kit as well and writes the
-- mark itself. See Curse.noticed for why that is one ledger rather than two.
GATES.cursed = function(player, want)
    return is(require("models.curse").noticed(player), want)
end

GATES.quest = function(player, questId)
    return player ~= nil and require("models.player").hasCompleted(player, questId) == true
end

-- Is one offer open for this player? `vendorId` is the house the offer stands in, handed to any gate
-- that has to hop through the vendor to read its class (see the block above -- no gate does today).
-- A nil gate is open; an unknown gate key is a typo in a blueprint and asserts rather than
-- silently reading as open -- a gate that quietly stops gating is a room delivered by accident.
-- EVENT, OR A BACKSTOP. `any = { ... }` holds when ANY of its sub-gates does, which is what lets a room
-- keep the gate that makes it land well AND still be guaranteed to arrive:
--
--     gate = { any = { { unidentified = true }, { trips = 5 } } }
--
-- "when you are holding something nobody can read, or by your fifth trip at the latest." The event is
-- the moment worth having -- a card arriving with exactly the problem it solves -- and the count is
-- there so a player the event never fires for is not quietly locked out of a room forever. Every other
-- key ANDs, as before.
function Offer.open(player, gate, vendorId)
    if gate == nil then return true end
    assert(type(gate) == "table", "an offer gate must be a table, got " .. type(gate))
    for key, value in pairs(gate) do
        if key == "any" then
            local held = false
            for _, sub in ipairs(value) do
                if Offer.open(player, sub, vendorId) then held = true; break end
            end
            if not held then return false end
        else
            local fn = GATES[key]
            assert(fn, "unknown offer gate '" .. tostring(key) .. "'")
            if not fn(player, value, vendorId) then return false end
        end
    end
    return true
end

-- Every offer this building declares, as a list of { answer, panel, gate, open }. Order is the
-- blueprint's, because that is the order the author wrote the desk in.
-- A FOLDED ROOM KEEPS ITS OWN VENDOR. Only the CARD went.
--
-- An offer may name a `vendor` of its own, and the counter hands that to the panel instead of the
-- house's. It is what lets the Undercroft's desk open the town counter (`vendor = "market"`) beside the
-- fence's own shelf without the two shops being merged into one -- which is not a routing change but a
-- content one: `sellsAll` makes a Buy tab the market's two racks INSTEAD of a class ladder
-- (ui/panels/shop.lua), so one vendor holding both flags would have quietly deleted the rogue shelf.
--
-- The same field is why the Cafe's kitchen, the Touchstone's reading and the market's counter all still
-- have their own keeper, their own portrait and their own one-time greeting. Nothing about those rooms
-- moved except the door they are behind -- and `Identify.VENDOR` still reads "touchstone", so no save
-- has to be migrated for the stone to remember it has been visited.
function Offer.list(player, building)
    local out = {}
    for _, offer in ipairs((building and building.offers) or {}) do
        out[#out + 1] = {
            answer = offer.answer,
            panel = offer.panel,
            vendor = offer.vendor or building.vendor,
            gate = offer.gate,
            quiet = offer.quiet, -- open without announcing its house; see Offer.any
            -- The GATE is always asked of the house, never of the offer's own vendor: a gate on a desk
            -- line is about THIS house, and the room the line opens may well belong to somebody else
            -- (the town counter behind the fence's door).
            open = Offer.open(player, offer.gate, building.vendor),
        }
    end
    return out
end

-- The open offers as an id set: { shelf = true, mend = true }. This is what a counter hands the
-- conversation resolver, where the `offer` predicate reads it -- so a desk line and the door it is
-- behind are answering off the same call (see the header).
function Offer.openSet(player, building)
    local set = {}
    for _, offer in ipairs(Offer.list(player, building)) do
        if offer.open and offer.answer then set[offer.answer] = true end
    end
    return set
end

-- Is anything at all open behind this door? What models/building.lua asks before drawing the card.
--
-- A building that declares NO offers answers true: the Armory and the Rift are doors onto one thing
-- each and keep their own `unlock` gates, so "has no offers" must never read as "is shut".
--
-- A QUIET ROOM DOES NOT ANNOUNCE ITS HOUSE. `quiet = true` on an offer means it can be open without
-- putting the card on the plaza -- it is a room you find behind a door something else opened.
--
-- Every house's SHELF is quiet, and that is the rule this field exists for. A shelf is ungated -- it is
-- the house, and a shopfront that offers no shop is not a shopfront -- so without `quiet` all seven
-- cards would stand on the plaza on the first morning, onto rung-0 racks of five buyable rows apiece (a
-- counter stocks a ware only once the company has carried one out). The plaza reacts to a deed the
-- player can FEEL -- a wound, a trip home, a find nobody can read -- and browsing is not one of them.
--
-- THE CARD AND THE ROOM ARE TWO QUESTIONS, which is the whole of what this field buys. They used to be
-- one: the shelf carried a `classLevel = 1` gate that decided both, so a company with no rogue had no
-- Undercroft at all and the contradiction never showed. The fold put the door on the plaza for the
-- market's sake and left the shop behind it shut -- so the gate came off the room and `quiet` kept the
-- card where it belonged.
function Offer.any(player, building)
    local offers = (building and building.offers) or {}
    if #offers == 0 then return true end
    for _, offer in ipairs(offers) do
        if not offer.quiet and Offer.open(player, offer.gate, building.vendor) then return true end
    end
    return false
end

-- The room an answer names -- `{ panel, vendor }` -- or nil when the desk reported something that is not
-- a room (the Exit line, or an answer whose offer is gated shut). The caller opens nothing on a nil,
-- which is what makes "leave" the safe default for anything unrecognised.
function Offer.roomFor(player, building, answer)
    if not answer then return nil end
    for _, offer in ipairs(Offer.list(player, building)) do
        if offer.answer == answer then
            if not (offer.open and offer.panel) then return nil end
            return { panel = offer.panel, vendor = offer.vendor }
        end
    end
    return nil
end

return Offer
