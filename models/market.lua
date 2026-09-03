-- THE MARKET: what the one shop has out this morning.
--
-- Two racks, and the split is the whole design:
--
--   THE CORE       the bottom rung of every class, always on the counter. Basic consumables and the
--                  plain equipment a body needs to be equipped at all. Never rolled, never absent.
--   THE ROTATION   a handful of deeper wares dealt against how far this company has got, changing
--                  once a day.
--
-- WHY BOTH. A shop that rolled its entire stock would make a trip into town a slot machine, and the one
-- morning you need a healing potion is the morning it is not there -- which prices a NEED, and a need
-- is the one thing this project has settled it will never price. A shop that rolled nothing would have
-- no reason to be opened twice. The core answers the need; the rotation is the reason to look.
--
-- DETERMINISTIC FROM THE DAY, never re-rolled on opening. This is the rule models/request.lua
-- established for the board it used to draw and it is the same rule for the same reason: "I will come
-- back for it tomorrow" has to be a sentence that means something. Roll on each open and a player
-- learns to close and reopen the panel until the shop says yes, which is not a decision, it is a
-- lever.
--
-- Pure model: no love.graphics and no state switching, so it loads under the headless runner.

local Discipline = require("models.discipline")
local Item = require("models.item")
local Vendor = require("models.vendor")

local Market = {}

-- The vendor blueprint this reads (data/vendors/market.lua). Named once so nothing else has to spell
-- it, and so the id and the file cannot drift apart.
Market.ID = "market"

-- The rung at or below which a ware is CORE -- always on the counter, whatever the day says.
--
-- Nought, which is to say: the opening band of every class, the gear the grade put on the bottom rung
-- because it is what a body starts with. Everything above it is the rotation's to offer.
Market.CORE_RUNG = 0

-- How many rotating wares the counter carries. Twelve against a stock of several hundred, so any given
-- morning shows a readable slice rather than a catalogue -- and so that what is out today is a fact a
-- player can hold in their head and come back for.
Market.ROTATION = 12

-- ---------------------------------------------------------------------------
-- The tier: how far along this company is
-- ---------------------------------------------------------------------------
--
-- THREE READINGS, AND THE HIGHEST OF THEM WINS. Not their average, and the difference matters:
--
--   depth            the deepest floor this company has ever stood on (Descent.deepest)
--   the specialist   the best class level any one body holds (Discipline.rosterLevel)
--   the spread       total class levels across the roster, over the seven classes
--
-- Averaging three numbers that already move together adds no information over the first of them and
-- hides which one is doing the work. Taking the maximum is what earns the word: a company that went
-- deep without committing to anything, and one that committed hard without going deep, both open stock
-- worth their while -- and each reading names its own decision instead of being diluted by the other
-- two.
--
-- Capped at the class ladder's own height so the tier and a rung are the same unit, which is what lets
-- the rotation filter on `unlockQuests` directly.
function Market.tier(player)
    local Descent = require("models.descent")
    local cap = Discipline.CLASS_LEVEL_CAP

    local depth = Descent.deepest(player)

    local best, total = 0, 0
    for _, char in ipairs((player and player.roster) or {}) do
        for key in pairs(char.technique or {}) do
            local n = Discipline.classLevel(char, key)
            total = total + n
            if n > best then best = n end
        end
    end

    -- Item.CLASSES is keyed by class id rather than being a list, so it is counted rather than
    -- measured with `#` -- which answers 0 on a map and would divide by nought here.
    local classes = 0
    for _ in pairs(Item.CLASSES) do classes = classes + 1 end

    local spread = math.floor(total / math.max(1, classes))
    return math.max(0, math.min(cap, math.max(depth, best, spread)))
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
    local key = item and (item.discipline or item.class)
    if not key then return Discipline.CLASS_LEVEL_CAP end
    return Discipline.rosterLevel(player, key)
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
-- The whole catalogue, locked rows included: seeing what a class opens is the point of a ladder, and
-- it is the same argument the seven shelves were built on. What the day decides is which of the
-- UNLOCKED ones are actually out (Market.stock).
function Market.catalogue(player)
    return Vendor.stock(Market.ID,
        function(item) return Market.rungFor(player, item) end,
        player and player.recipes,
        Discipline.unlockedSet(player),
        Discipline.levelSet(player))
end

-- What is on the counter on `day`: the core, plus the day's rotation, cheapest first.
--
-- The rotation is drawn from wares that are BUYABLE -- unlocked, and at or under the company's tier --
-- so a rolled row is always something the player can act on. A locked row in the rotation would be the
-- shop advertising at them, and the catalogue is already where you go to see what is coming.
function Market.stock(player, day)
    day = day or 1
    local tier = Market.tier(player)

    local core, pool = {}, {}
    for _, row in ipairs(Market.catalogue(player)) do
        if (row.unlockQuests or 0) <= Market.CORE_RUNG and not row.locked then
            core[#core + 1] = row
        elseif not row.locked and (row.unlockQuests or 0) <= tier then
            pool[#pool + 1] = row
        end
    end

    table.sort(pool, function(a, b)
        local ha, hb = dayHash(a.id, day), dayHash(b.id, day)
        if ha ~= hb then return ha < hb end
        return a.id < b.id
    end)

    local out = {}
    for _, row in ipairs(core) do out[#out + 1] = row end
    for i = 1, math.min(Market.ROTATION, #pool) do out[#out + 1] = pool[i] end

    table.sort(out, function(a, b)
        if a.unlockQuests ~= b.unlockQuests then return a.unlockQuests < b.unlockQuests end
        if a.price ~= b.price then return a.price < b.price end
        return a.name < b.name
    end)
    return out
end

-- ---------------------------------------------------------------------------
-- The dot: what opened while you were down there
-- ---------------------------------------------------------------------------
--
-- A RUNG CAN OPEN WITH NOBODY WATCHING, and that is the hole this closes. A shelf used to climb when a
-- quest was finished, so there was one seam -- Quest.complete -- that could take a BEFORE picture of the
-- shelf, do the ledger write, and mark whatever came unlocked (Quest.markOpenedStock). A shelf climbs
-- on a class level now, and a class level rises out of ordinary swinging: two technique an action,
-- banked in the middle of a fight by Combat.awardTechnique. There is no moment to wrap.
--
-- SO IT IS A WATERMARK RATHER THAN A DIFF. `player.shelfRung` records the rung each class had reached
-- the last time this was asked; anything sitting between that and where the class stands now is stock
-- the player has not been told about. No BEFORE picture to take, nothing to forget to wrap, and it is
-- correct however many rungs were crossed between two calls -- a company that goes down at knight 2 and
-- comes up at knight 5 is told about all three.
--
-- WHY NOT MARK LAZILY, when the shelf is next built: because every unlocked row would be new on a fresh
-- save, and a dot that is on from the first morning is a dot that means nothing. A watermark starts at
-- nought and the opening band is silently absorbed by the first call, which is right -- the player is
-- looking at the opening band when they arrive.
--
-- Marks through Player.markNew, which is what draws the dot on the row AND, through
-- Vendor.hasMarkedStock, the dot on the market's door out in the city. Cleared by reading, not by
-- acting: Player.seeNew, in the shop.
function Market.markOpened(player)
    if not player then return nil end
    local Player = require("models.player")

    player.shelfRung = player.shelfRung or {}
    local risen = {}
    for class in pairs(Item.CLASSES) do
        local now = Discipline.rosterLevel(player, class)
        local was = player.shelfRung[class] or 0
        if now > was then
            risen[class] = { was = was, now = now }
            player.shelfRung[class] = now
        end
    end
    if not next(risen) then return nil end

    -- Walked over the blueprints rather than over Market.catalogue, because what is being asked is
    -- "which rows crossed a rung", and that is a question about numbers rather than about the shelf's
    -- current shape. A ware whose discipline is still locked is deliberately skipped: it did not open,
    -- and dotting a row the player cannot buy is the dot lying.
    local opened = {}
    local unlocked = Discipline.unlockedSet(player)
    for id, def in pairs(Item.defs) do
        if def.price then
            local key = def.discipline or def.class
            local band = key and risen[def.class]
            if band and (not def.discipline or unlocked[def.discipline]) then
                local rung = def.unlockQuests or 0
                if rung > band.was and rung <= band.now then
                    Player.markNew(player, Player.NEW_STOCK, id)
                    opened[#opened + 1] = id
                end
            end
        end
    end

    if #opened == 0 then return nil end
    table.sort(opened)
    return { items = opened, classes = risen }
end

return Market
