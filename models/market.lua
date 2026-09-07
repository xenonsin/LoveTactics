-- THE MARKET: what the one shop has out this morning.
--
-- Two racks, and the split is the whole design:
--
--   THE COUNTER    the plain kit, standing. Every opening-rung consumable, and every class's plain
--                  opening-rung weapon -- that class's blade once its companion has actually joined.
--                  Never rolled, never absent. Twenty-two rows when the whole company is recruited.
--   TODAY          three deeper wares dealt against how far this company has got, changing once a day.
--
-- WHY BOTH. A shop that rolled its entire stock would make a trip into town a slot machine, and the one
-- morning you need a healing potion is the morning it is not there -- which prices a NEED, and a need
-- is the one thing this project has settled it will never price. A shop that rolled nothing would have
-- no reason to be opened twice. The counter answers the need; today's three are the reason to look.
--
-- WHY IT IS NOT THE CATALOGUE, which is what it was until this was written. The seven houses became
-- seven classes and their seven shelves became one counter, and the counter inherited every ware all
-- seven had ever stocked: 485 priced items, 235 of them with no discipline to band them, all listed at
-- once and NONE of them locked -- because Quest.shelfRung answers the class level cap for a vendor with
-- no class, and the market is deliberately classless (`sellsAll`). Twenty-six screens of stock, every
-- piece of it buyable on the first morning. This file already existed and already said "a readable
-- slice rather than a catalogue"; what it did not have was a caller. ui/panels/shop.lua asked
-- Vendor.stock directly, exactly as it had when a house had a shelf of its own. Prose is not an
-- implementation.
--
-- WHAT A COUNTER IS FOR, now that the catalogue is not on it. The deep end of the ladder is reached by
-- descending -- taken off the bodies that carried it (models/spoils.lua), bought off the cart on the
-- road, bled for at a stone -- and, since the seven houses came back on a class gate, by climbing the
-- class whose shelf sells it (data/buildings/houses.lua). The town shop is where you replace what you
-- spent and arm a body you just recruited, and the three rolled rows are the reason to come back
-- tomorrow. No LADDER is greyed here: a rotation is not a ladder, and a rung-locked row on a counter
-- this small is the shop advertising at you. The ladders are next door, and they do their own banding.
--
-- ONE EACH OFF TODAY'S RACK, and that is the only thing this counter ever greys. The three rolled rows
-- are the perishable half -- what is out today and gone by morning -- and a row a player can buy four
-- of is not out today, it is simply cheap. So a purchase takes that row off the counter until the roll
-- turns over (Market.recordSold), and the row is GREYED WHERE IT STOOD rather than removed: the rack is
-- three tiles wide and the whole of it is the day's news, so a rack that shortens as you shop reads as
-- stock that was never dealt. THE STANDING RACK IS NEVER TOUCHED BY THIS -- it is the answer to a need,
-- and a need is the one thing this file has settled it will not price.
--
-- DETERMINISTIC FROM THE DAY, never re-rolled on opening. This is the rule models/request.lua
-- established for the board it used to draw and it is the same rule for the same reason: "I will come
-- back for it tomorrow" has to be a sentence that means something. Roll on each open and a player
-- learns to close and reopen the panel until the shop says yes, which is not a decision, it is a
-- lever.
--
-- Pure model: no love.graphics and no state switching, so it loads under the headless runner.

local Class = require("models.class")
local Errand = require("models.errand") -- doorOpen: has this class's companion joined
local Item = require("models.item")
local Vendor = require("models.vendor")

local Market = {}

-- The vendor blueprint this reads (data/vendors/market.lua). Named once so nothing else has to spell
-- it, and so the id and the file cannot drift apart.
Market.ID = "market"

-- The two racks, as the tag a stock row wears. The shop bands on this and nothing else, which is why
-- it is a field on the row rather than two return values: a row knows which rack it came off, and a
-- caller that does not care can ignore it and read one list.
Market.COUNTER = "counter"
Market.TODAY = "today"

-- What the standing rack holds, and it is a TYPE question rather than a price one.
--
-- Consumables and weapons. Not armor and not utility, and that is a reading of the data rather than a
-- taste: there is no plain armor at the opening rung. The only two pieces down there are the Muster
-- Cuirass and Rimeguard, both named knight gear, both things you are meant to find. A body walks in
-- wearing what it came with and buys the blade and the draught.
Market.STAPLE_TYPES = { consumable = true, weapon = true }

-- The rung at or below which a ware of a staple type is standing stock.
--
-- Nought, which is to say: the opening band of every class, the gear the grade put on the bottom rung
-- because it is what a body starts with. Everything above it is the rotation's to offer.
Market.STAPLE_RUNG = 0

-- How many rotating wares the counter carries. Three against a stock of several hundred, so what is out
-- today is a fact a player can hold in their head and come back for. It was twelve, which is a list you
-- read rather than three things you decide between.
Market.ROTATION = 3

-- ---------------------------------------------------------------------------
-- What is already off today's rack
-- ---------------------------------------------------------------------------
--
-- STAMPED WITH THE DAY IT BELONGS TO, and that is what makes it self-expiring: `player.marketSold` is
-- one record, `{ day = n, ids = { [id] = true } }`, and a record whose day is not today's answers
-- nothing at all. No sweep to run on the night seam, nothing for models/gate.lua to remember to clear,
-- and no way for yesterday's shopping to grey a row out of tomorrow's roll -- which is the failure a
-- growing set of ids would have, since the roll can deal the same ware again next week.
--
-- One record rather than a set per day for the same reason: a day that is over is not a thing anybody
-- can ask about, so keeping it is a save file that grows for the life of a campaign.

-- The ids already bought off today's rack, or nil when nothing on `day` has been.
function Market.soldToday(player, day)
    local rec = player and player.marketSold
    if not (rec and rec.day == (day or 1)) then return nil end
    return rec.ids
end

function Market.isSold(player, day, id)
    local ids = Market.soldToday(player, day)
    return (ids and ids[id]) == true
end

-- Take `id` off today's rack. Called on the COMMIT of a purchase (ui/panels/shop.lua's commitBuy) and
-- only for a row that came off Market.TODAY -- the standing rack sells the same draught all day.
function Market.recordSold(player, day, id)
    if not (player and id) then return end
    day = day or 1
    local rec = player.marketSold
    if not (rec and rec.day == day) then
        rec = { day = day, ids = {} }
        player.marketSold = rec
    end
    rec.ids[id] = true
end

-- ---------------------------------------------------------------------------
-- The counter: the plain kit, standing
-- ---------------------------------------------------------------------------

-- Is `item` standing stock -- the plain kit, as opposed to something the rotation deals?
--
-- Three tests, and each is doing work. AN EARNED CLASS is the deeper cut and never plain, so it
-- disqualifies whatever else is true. The TYPE is the sentence above. The RUNG is the grade's own word
-- for "this is what a body starts with" (docs/shelf.md) -- and it is the one of the three that keeps
-- this set honest as the catalogue is authored out, since a new weapon written at rung 0 on a root
-- class is, by every definition this project has, plain kit.
--
-- The first test read `item.discipline` before the fold, which is the same sentence in the vocabulary
-- of two fields (docs/class-fold.md). With one field a truthiness check would answer false forever and
-- let a crossing's gear onto the standing rack.
function Market.isStaple(item)
    if not (item and item.price) then return false end
    if item.class and not Class.isRoot(item.class) then return false end
    if not Market.STAPLE_TYPES[item.type] then return false end
    return (item.unlockQuests or 0) <= Market.STAPLE_RUNG
end

-- Will the market actually put this staple out for THIS company?
--
-- A DRAUGHT ALWAYS, A BLADE WHEN ITS COMPANION HAS JOINED. The nine Iron pieces and the four that are
-- not named for the ore -- Staff and Wand, Censer, Apothecary's Lancet -- are one weapon per class at
-- one price, and which of them are on the counter is the clearest reading the city has of who is
-- actually in your company: recruit Rowan and the Bastion's blades appear, recruit Gyeom and the wands
-- do. It is also what keeps the opening morning small, since only one house has answered you yet.
--
-- Consumables are never gated, and the reason is the one the whole counter is built on: seven of the
-- nine are the Crucible's, so gating them would put healing potions behind recruiting Ren, and that
-- prices a need.
function Market.stocksStaple(player, item)
    if not item then return false end
    if item.type ~= "weapon" then return true end
    local house = Vendor.forClass(Item.classOf(item))
    if not house then return true end
    return Errand.doorOpen(player, house)
end

-- ---------------------------------------------------------------------------
-- The tier: how far along this company is
-- ---------------------------------------------------------------------------
--
-- ONE READING: THE DEEPEST FLOOR THIS COMPANY HAS EVER STOOD ON (Descent.deepest), and what the
-- counter deals is what that floor is worth.
--
-- IT USED TO BE THREE -- depth, the best class level any one body held, and the roster's total spread
-- over the seven roots -- with the highest winning. The argument was that a company which committed
-- hard without going deep should still open stock worth its while, and it is a decent argument about
-- CLASS LEVELS. It is the wrong argument about a shop. A counter is stocked against what the company
-- has SEEN, not against what it has practised: the deep end of this catalogue is a place, the player
-- goes there and comes back knowing what is down there, and the shop is the city answering that. Two
-- of the three readings could carry the counter past a floor nobody had walked, which is the shop
-- telling the player about goods on a floor they have not met.
--
-- IN THE RIFT'S OWN UNIT, and that is the half that was quietly wrong rather than merely arguable.
-- `deepest` is a floor NUMBER and a floor is worth two levels (Descent.LEVEL_PER_FLOOR), so reading
-- the number raw had the counter running at half the ladder the floors themselves deal on: standing on
-- floor five, the rift gives up its tier-8 finds (models/spoils.lua) and the market was still banding
-- at 5. Descent.floorLevel is the conversion, and it is the same one every other depth reading in the
-- game makes.
--
-- Capped at the class ladder's own height so the tier and a rung are the same unit, which is what lets
-- the rotation filter on `unlockQuests` directly. Nought for a company that has never gone down: the
-- counter opens on its standing rack, which is the plain kit and is never banded.
function Market.tier(player)
    local Descent = require("models.descent")
    local deepest = Descent.deepest(player)
    if deepest <= 0 then return 0 end
    return math.min(Class.CLASS_LEVEL_CAP, Descent.floorLevel({ floor = deepest }))
end

-- ---------------------------------------------------------------------------
-- What is on the counter
-- ---------------------------------------------------------------------------

-- The rung the player has reached in `item`'s own class or discipline -- the roster's best holder, for
-- the same reason every company-facing reading of the ladder takes the best: specializing one body is
-- what opens the deep end, and spreading the same tally over four does not.
--
-- A classless ware -- creature kit that slipped onto a price -- answers the cap, so it is never locked
-- behind a ladder it does not sit on.
function Market.rungFor(player, item)
    local key = item and item.class
    if not key then return Class.CLASS_LEVEL_CAP end
    return Class.rosterLevel(player, key)
end

-- A stable, seedless shuffle key for `id` on `day`. Deliberately arithmetic rather than math.random:
-- the rotation has to be the same for one player on one day however many times the panel is opened,
-- and reproducible in a spec, and neither survives touching the global generator.
-- Multiplicative rather than the usual xor-and-mask: this runs on Lua 5.1 (LOVE's interpreter), which
-- has no bitwise operators at all, and the modulus keeps it inside a double's exact integer range.
local function dayHash(id, day)
    local h = 5381
    local s = tostring(id) .. ":" .. tostring(day)
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 2147483647
    end
    return h
end

-- Everything the market could ever sell, as Vendor.stock rows, each gated on ITS OWN class's ladder.
--
-- The whole catalogue, locked rows included. This is the POOL the two racks are drawn from and not
-- something any screen lists: what a player sees is Market.stock.
function Market.catalogue(player)
    return Vendor.stock(Market.ID,
        function(item) return Market.rungFor(player, item) end,
        player and player.recipes,
        Class.unlockedSet(player),
        Class.levelSet(player))
end

-- What is on the counter on `day`: today's three, then the standing rack. Each row carries `rack`.
--
-- Both racks are BUYABLE, always -- until one of today's three is bought. The rotation draws from wares
-- that are unlocked and at or under the company's tier, so a rolled row is always something the player
-- can act on, and the standing rack is plain kit that is never locked by definition. The one lock this
-- counter deals is `sold`: a rolled row this company has already taken today, greyed where it stands
-- (see the header). It carries `locked` too, so every reader that already refuses a shut row -- the
-- press, the tile, the tooltip's refusal -- refuses this one without being taught a new word.
function Market.stock(player, day)
    day = day or 1
    local tier = Market.tier(player)
    local sold = Market.soldToday(player, day)

    local counter, pool = {}, {}
    for _, row in ipairs(Market.catalogue(player)) do
        local item = Item.defs[row.id]
        if Market.isStaple(item) then
            if Market.stocksStaple(player, item) then
                row.rack = Market.COUNTER
                counter[#counter + 1] = row
            end
        elseif not row.locked and (row.unlockQuests or 0) <= tier then
            pool[#pool + 1] = row
        end
    end

    table.sort(pool, function(a, b)
        local ha, hb = dayHash(a.id, day), dayHash(b.id, day)
        if ha ~= hb then return ha < hb end
        return a.id < b.id
    end)

    -- SOLD IS STAMPED AFTER THE DEAL, never filtered before it: the three rows a day deals are a fact
    -- about the day, and dropping a bought one here would promote a fourth ware onto a rack the player
    -- has already read. The row keeps its place and goes grey.
    local today = {}
    for i = 1, math.min(Market.ROTATION, #pool) do
        local row = pool[i]
        row.rack = Market.TODAY
        if sold and sold[row.id] then
            row.sold, row.locked, row.lockReason = true, true, "sold"
        end
        today[#today + 1] = row
    end

    -- Cheapest first WITHIN a rack, and the racks stay in their order. Sorting the whole list would
    -- interleave the three rolled rows through the twenty-two standing ones, which is exactly the
    -- reading the split exists to prevent.
    --
    -- TODAY LEADS. The standing rack is standing -- it will be there tomorrow and the day after, and a
    -- player who wants a bandage already knows where it lives. The three rolled rows are the only thing
    -- on this counter that is gone by morning, so they take the top of the list, where the eye lands
    -- and where nothing has to be scrolled past to reach them.
    local function shelfOrder(a, b)
        if a.unlockQuests ~= b.unlockQuests then return a.unlockQuests < b.unlockQuests end
        if a.price ~= b.price then return a.price < b.price end
        return a.name < b.name
    end
    table.sort(counter, shelfOrder)
    table.sort(today, shelfOrder)

    local out = {}
    for _, row in ipairs(today) do out[#out + 1] = row end
    for _, row in ipairs(counter) do out[#out + 1] = row end
    return out
end

-- ---------------------------------------------------------------------------
-- The dot: what opened while you were down there
-- ---------------------------------------------------------------------------
--
-- A RACK CAN OPEN WITH NOBODY WATCHING, and that is the hole this closes. A companion is recruited on a
-- floor, in the middle of a run (models/errand.lua), and their class's blades go onto the counter back
-- in the city -- where the player is not standing, and will not be for another hour of play.
--
-- SO IT IS A WATERMARK RATHER THAN A DIFF. `player.marketRacks` records which classes' racks the player
-- has already been told about; a class whose companion has joined since is news. No BEFORE picture to
-- take and nothing to forget to wrap, and it is correct however many companions joined between two
-- calls.
--
-- IT USED TO WATERMARK CLASS LEVELS, and that stopped being true the moment the counter did. A class
-- level rising widens the ROTATION POOL -- it promises nothing in particular, and the three rows dealt
-- tomorrow are as likely as not to come from somewhere else entirely. Marking those ids dotted rows
-- that were not out, which is a dot that cannot be cleared by reading (Player.seeNew only fires on a
-- row the cursor can land on) and therefore a door that stays lit for good. A mark is only ever put on
-- something the player can walk in and see.
--
-- Marks through Player.markNew, which is what draws the dot on the row AND, through
-- Vendor.hasMarkedStock, the dot on the market's door out in the city. Cleared by reading, not by
-- acting: Player.seeNew, in the shop.
function Market.markOpened(player)
    if not player then return nil end
    local Player = require("models.player")

    player.marketRacks = player.marketRacks or {}
    local risen = {}
    for class in pairs(Class.roots()) do
        local house = Vendor.forClass(class)
        if house and Errand.doorOpen(player, house) and not player.marketRacks[class] then
            player.marketRacks[class] = true
            risen[class] = true
        end
    end
    if not next(risen) then return nil end

    -- Walked over the blueprints rather than over Market.stock, because what is being asked is "which
    -- staples does this class own", and that does not depend on which day it is.
    local opened = {}
    for id, def in pairs(Item.defs) do
        if risen[Item.classOf(def)] and Market.isStaple(def) then
            Player.markNew(player, Player.NEW_STOCK, id)
            opened[#opened + 1] = id
        end
    end

    if #opened == 0 then return nil end
    table.sort(opened)
    return { items = opened, classes = risen }
end

return Market
