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
-- ...AND WHETHER A ROOM HAS ANYTHING WAITING IN IT TODAY, which is a second question over the same
-- rooms and lives at the bottom of this file: a gate says the mending line EXISTS, and Offer.news says
-- somebody is actually hurt. The door's red dot and the desk line's are the OR and the one entry of
-- that same call (Offer.anyNews / Offer.newsSet), for the same reason the gate is one call.
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

-- SOMEBODY IN THIS COMPANY IS TRAINING FOR WHAT THIS HOUSE SELLS.
--
-- The gate the block above said any successor would take: it hops through the vendor, because what it
-- has to know is the house's CLASS and a house does not write one on itself (data/vendors/<id>.lua).
--
-- WHY IT EXISTS. Every house's shelf is quiet -- it may not put a card on the plaza (Offer.any) -- so
-- the seven class houses arrived in the order their OTHER rooms happened to be scheduled: the Colosseum
-- on the duel, the Arcanum on the bestiary, the Alchemist on the reading. Fighter was not last because
-- fighter gear is late content. It was last because PvP is last. Meanwhile no root class has a
-- `requires` at all (data/classes/), so a player can declare Fighter on the first morning and then walk
-- five trips with nowhere to buy a fighter ability. The clock was pacing rooms and accidentally pacing
-- CLASSES, which is not a thing rooms know how to pace.
--
-- So intent opens the house. Declare a class in the Roll -- or hire a body born to one -- and the house
-- that shelves it is on the square before the panel has finished closing. The trips gate on each
-- house's other room is untouched and is still the backstop: a player who declares nothing sees exactly
-- today's schedule, and the duel is still the seventh trip either way.
--
-- ASKED OF THE SHELF, not of the root, so a body declared Ninja opens both the houses that sell a
-- Ninja's gear (Vendor.shelves) -- the same rule the rack itself already runs on.
--
-- One-way, via Class.taken: changing class back must never take a card off the plaza.
GATES.declared = function(player, want, vendorId)
    local Vendor = require("models.vendor")
    local def = vendorId and Vendor.defs[vendorId]
    local held = false
    if def and player then
        for class in pairs(require("models.class").takenSet(player)) do
            if Vendor.shelves(def, class) then held = true; break end
        end
    end
    return is(held, want)
end

-- Is one offer open for this player? `vendorId` is the house the offer stands in, handed to any gate
-- that has to hop through the vendor to read its class -- `declared` above is the one that does.
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
            quiet = offer.quiet,       -- open without announcing its house; see Offer.any
            announce = offer.announce, -- ...except on this gate. Also Offer.any
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
--
-- ...AND `announce` IS THE ONE CONDITION UNDER WHICH A QUIET ROOM SPEAKS UP. It is a gate in the same
-- vocabulary as `gate`, asked only of a room that is already open, and it decides the CARD alone --
-- never whether the room is there. The two fields are two questions and a quiet shelf has to answer
-- them differently: it is open always (a shopfront offers a shop), and it announces only when the
-- company is actually training for what it sells (`declared`, above).
--
-- That is what took the class houses off the room queue. Browsing is still not a deed the player can
-- feel, which is why the shelf is still quiet by default -- but DECLARING A CLASS is, and it is the
-- loudest one the Roll has. See GATES.declared for the whole argument.
function Offer.announces(player, offer, vendorId)
    if not offer.quiet then return true end
    return offer.announce ~= nil and Offer.open(player, offer.announce, vendorId)
end

function Offer.any(player, building)
    local offers = (building and building.offers) or {}
    if #offers == 0 then return true end
    for _, offer in ipairs(offers) do
        if Offer.open(player, offer.gate, building.vendor)
            and Offer.announces(player, offer, building.vendor) then
            return true
        end
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

-- ---------------------------------------------------------------------------
-- IS THERE ANYTHING WAITING IN THIS ROOM -- the red dot
-- ---------------------------------------------------------------------------
--
-- A GATE SAYS THE ROOM EXISTS; THIS SAYS IT HAS SOMETHING FOR YOU TODAY. Two different questions, and
-- the desk needs both: the Cathedral's mending line stands on that desk forever once anybody has been
-- carried up broken (that is the gate doing its job), but it is only worth walking into on the trips
-- where somebody is actually hurt. So the line wears a mark, and the mark is this.
--
-- THE DOOR AND THE LINE ARE ONE CALL, for the reason the header gives about the gate and for a failure
-- this project has now shipped twice: a mark raised on a looser question than the screen behind it
-- clears on is a mark the player cannot put out. They walk in, read everything, walk out, and the plate
-- is still burning. So states/hub.lua's plate is the OR over these (Offer.anyNews) and a desk line is
-- the one entry (Offer.newsSet) -- neither derives its own answer.
--
-- Keyed by PANEL rather than by answer, because the answer is the desk's word for a room ("mend",
-- "lift", "read") and the panel is the room. Two houses could offer the same room under different
-- words; nobody does today, and this way nobody has to remember not to.
--
-- EVERY ONE OF THESE IS A STATE, NOT A SIGHTING, with one deliberate exception. A wound, a hex and an
-- unread find are things the company is still CARRYING -- a dot that went out on the first look would
-- stop reminding the player at the exact moment they decided to deal with it after the next trip -- so
-- they clear when the thing is dealt with, not when it is seen. The exception is a shelf, whose whole
-- ledger is a sighting (Player.seeNew): stock is news, and news is read.
--
-- WHAT IS DELIBERATELY NOT HERE IS THE FORGE. "Something in the kit is damaged" is true after almost
-- every trip, so a bench dot would be lit permanently within an hour and would teach the player that a
-- dot on this board means nothing. A mark has to be able to go out.
local NEWS = {}

-- SOMEBODY IS HURT AND NOBODY HAS SEEN TO THEM YET. `unattended` rather than `wounded`: a body already
-- lying up is being dealt with (the stay is served by descending -- models/wound.lua), and a room that
-- went on flagging it would be asking for a decision the player has made.
NEWS.ward = function(player)
    return #require("models.wound").unattended(player) > 0
end

-- SOMETHING THE COMPANY OWNS IS HEXED (models/curse.lua). Counts the kit AND the stash, which is what
-- Curse.count already walks -- a hex shelved rather than paid for is still a hex the rite would finish.
NEWS.rite = function(player)
    return require("models.curse").count(player) > 0
end

-- THE SATCHEL HOLDS SOMETHING NOBODY CAN READ (models/identify.lua). The most literal mark on the
-- board: the player is carrying dead weight until this room is walked into.
NEWS.touchstone = function(player)
    return require("models.identify").count(player) > 0
end

-- A SHELF WITH SOMETHING ON IT NOBODY HAS LOOKED AT. See Offer.shelfNews.
NEWS.shop = function(player, vendorId)
    return Offer.shelfNews(player, vendorId)
end

-- Has this counter got a marked ware the player can actually be shown?
--
-- ASKED THROUGH THE SHELF'S OWN GATES (Quest.shelfGates) rather than of the catalogue. A mark can be
-- laid on a ware sitting rungs above where the company is standing, and ui/panels/shop.lua draws no
-- unseen dot on a row it cannot sell -- so a door asking only "does this house SELL a marked ware" lit
-- for stock the rack will not mark, and the dot was still burning when the player walked out having
-- read the lot. The gate makes the mark ask exactly what the rack answers, and the mark KEEPS: it
-- lights on the day the ladder reaches the row, which is the only announcement a shelf opened by a
-- class level ever gets.
--
-- THE MARKET IS ASKED OF ITS COUNTER, not of its shelf, and it is the one room that has to be.
-- `sellsAll` makes the shelf question answer yes for every ware in the game (models/vendor.lua's
-- Vendor.sells), so this lit for every discovery the company carried home -- two dozen wares the
-- counter is not showing, and therefore a mark with nothing behind it that could clear. Market.hasUnread
-- asks the standing rack.
--
-- Requires inline, the way the gates above do: a new top-level require reorders `pairs` over the
-- registry, which is enough on its own to redden a spec that has nothing to do with this file.
function Offer.shelfNews(player, vendorId)
    if not (player and vendorId) then return false end
    local Market = require("models.market")
    if vendorId == Market.ID then return Market.hasUnread(player) end
    if not player.newStock then return false end
    local gates = require("models.quest").shelfGates(player, vendorId)
    return require("models.vendor").hasMarkedStock(vendorId, player.newStock, gates) == true
end

-- Is anything waiting behind ONE room? `offer` is an entry from Offer.list. A room that is not open yet
-- never carries a mark: a dot for a line the desk will not print is a dot with nothing behind it that
-- the player could clear.
function Offer.news(player, offer)
    if not (player and offer and offer.open and offer.panel) then return false end
    local fn = NEWS[offer.panel]
    if not fn then return false end
    return fn(player, offer.vendor) == true
end

-- The rooms with something waiting, as an id set keyed by ANSWER: { mend = true }. The mirror of
-- Offer.openSet, and what a counter hands the conversation resolver so each desk line can wear its own
-- mark (models/counter.lua).
function Offer.newsSet(player, building)
    local set = {}
    for _, offer in ipairs(Offer.list(player, building)) do
        if offer.answer and Offer.news(player, offer) then set[offer.answer] = true end
    end
    return set
end

-- Is anything waiting behind this DOOR -- the OR over its open rooms. What the plate on the plaza wears
-- (states/hub.lua), so the city says which door to walk through before any of them is opened.
--
-- A QUIET ROOM STILL COUNTS, unlike Offer.any above, and the difference is what each question is for.
-- `quiet` decides whether a room may ANNOUNCE ITS HOUSE -- put a card on the plaza that was not there
-- yesterday -- and a shelf may not, because a class rung is not a deed the player can feel. A mark on a
-- door already standing is not an announcement; it is the house saying there is something inside, which
-- is exactly what a shelf with unread stock on it is.
--
-- A door that keeps a shelf and declares no rooms at all (nothing does today; the Armory's shape is one
-- blueprint away from it) is asked about its own counter.
function Offer.anyNews(player, building)
    local offers = (building and building.offers) or {}
    if #offers == 0 then
        return building ~= nil and building.vendor ~= nil and Offer.shelfNews(player, building.vendor)
    end
    for _, offer in ipairs(Offer.list(player, building)) do
        if Offer.news(player, offer) then return true end
    end
    return false
end

return Offer
