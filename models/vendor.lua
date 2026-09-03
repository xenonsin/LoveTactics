-- Vendor logic. Blueprints live in data/vendors/<id>.lua: a class vendor's identity.
-- Vendors are decoupled from hub geometry (data/buildings/) so a quest can name a sponsor
-- without knowing where its building stands, and from the player (every gate here takes a
-- plain count of quests-completed, not a player) so models/player.lua and this module do
-- not form a require cycle.
--
-- A vendor SELLS. It does not upgrade: every ladder in the game is climbed at the one Forge
-- (models/forge.lua), which is also the only bench that spends materials. This module used to carry a
-- second door onto the same `item.level` -- abilities honed at their class vendor, consumables refined
-- per-type -- and having two doors onto one ladder meant two bills, two ceilings, and no single place
-- to look. Standing with a house is still the ceiling on how far its gear forges, but the Forge now
-- counts that itself (Forge.ceilingFor, off Quest.sponsorProgress) rather than borrowing a ladder
-- from here.
--
-- A shelf opens as you run the vendor's OWN quest line: each priced item names how many of
-- that sponsor's quests you must have finished before it is on sale (`unlockQuests`, default
-- 0 -- open from the start). There is no reputation score and no rank titles; the only number
-- the player ever sees is "quests completed with this house", counted from the sponsor of
-- each quest in player.completedQuests (models/quest.lua's Quest.sponsorProgress).
--
-- Stock is *derived, not authored*: a vendor sells every priced item whose `class` matches its
-- own. Adding data/items/<slot>/<id>.lua with the right class puts it on that vendor's shelf.
--
-- One vendor is different: the Cafe declares `sells = false` and stocks NOTHING. It used to be the
-- general store -- the shelf for classless priced goods, plus a resale rack for every `potion`. Both
-- are gone: the five classless wares were given the houses that actually wanted them, and the resale
-- was a way to walk around the Crucible's own ladder. What the Cafe sells now is a meal before the
-- road, which is not an item at all (models/meal.lua, docs/meals.md). It keeps a blueprint here
-- because it keeps a shopkeeper -- a portrait, a name, a first-visit greeting.
--
-- The flag is stated on the vendor rather than assumed from an empty shelf, so an item that loses its
-- class by accident lands nowhere rather than quietly on the grocer's counter -- and so
-- tests/progression_spec.lua's "every priced item has a shelf" catches it.

local Registry = require("models.registry")
local Item = require("models.item")
local Discipline = require("models.discipline")

local Vendor = {}

Vendor.defs = Registry.load("data/vendors", "data.vendors")

function Vendor.get(id)
    return Vendor.defs[id]
end

-- The vendor id of the house that sells `class`, or nil for a classless one (the Cafe). Reverse-indexed
-- from the blueprints once, so the class -> house mapping lives in data rather than in a second table.
--
-- The single owner of that question. models/forge.lua asked it first (for a class item's ceiling) and
-- ui/panels/shop.lua now asks it too (to name the house a missing discipline parent is sold at), and
-- two private reverse indexes over the same field is exactly how they drift.
local byClass
function Vendor.forClass(class)
    if not class then return nil end
    if not byClass then
        byClass = {}
        for id, def in pairs(Vendor.defs) do
            if def.class then byClass[def.class] = id end
        end
    end
    return byClass[class]
end

-- Ordered list of vendors, for UI that enumerates them.
function Vendor.list()
    local list = {}
    for id, def in pairs(Vendor.defs) do
        list[#list + 1] = {
            id = id,
            name = def.name,
            class = def.class,
            description = def.description,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- (Vendor.TIERS / Vendor.tier -- the four-value wave enum { 0, 3, 6, 10 } -- used to live here. Item
-- gates left it when tools/unlock_rescale.lua rewrote all 339 onto per-quest `unlockQuests`, and the
-- Forge's class-item ceiling left it when that moved to Forge.CEILING_BASE + quests done. Nothing read
-- it after that, and a dead enum with no callers is exactly how the two halves of a house's offer
-- drifted onto different granularities in the first place, so it is deleted rather than kept around.)

-- The shelf price of a base item scaled to `level`: +50% of the base per tier, rounded. A consumable
-- refined to a higher recipe tier (Player.recipeLevel) is stocked and sold at this raised price. A nil
-- base (an item that was never for sale) stays nil. One place so shelf price and sell value agree.
function Vendor.priceFor(base, level)
    return base and math.floor(base * (1 + 0.5 * (level or 0)) + 0.5)
end

-- Whether `def` (a vendor blueprint) stocks `item`. A class vendor sells its own class; a vendor that
-- declares `sells = false` (the Cafe, whose whole offer is the meal menu) stocks nothing at all. One
-- rule, so the shop, the sell-back and the hub's new-stock dot all agree on what a shelf holds. Takes
-- the def rather than an id so stock can call it in a loop.
function Vendor.sells(def, item)
    if not def or not item then return false end
    if def.sells == false then return false end

    -- THE MARKET SELLS EVERYTHING. One shop replaced the seven houses, so the thing that used to be a
    -- taxonomy question -- is this ware on my shelf -- is answered for it by a flag rather than by a
    -- class it does not have. What gates a ware there is its rung and its price, not its house
    -- (models/market.lua).
    if def.sellsAll then return true end

    if Item.classOf(item) == def.class then return true end
    -- A discipline item also lands on each of its discipline's parent shelves. That is how a multiclass
    -- item (whose `class` is one parent, its home tally) appears on the OTHER parent's shelf too --
    -- shopping both shelves is literally how you build the thing. Derived from the discipline's
    -- `classes`, never authored per-shelf. (Whether it is buyable yet is Vendor.stock's `locked` job.)
    if item.discipline then
        for _, parent in ipairs(Discipline.parents(item.discipline)) do
            if parent == def.class then return true end
        end
    end
    return false
end

-- Every item this vendor could ever sell, in shelf order (cheapest first). Quest-gated items are
-- included; `locked` marks the ones the player has not earned yet, so the shop can show them greyed
-- out -- seeing what the rest of the line unlocks is the point of the ladder.
--
-- `questsDone` is the RUNG of this shelf the player has reached (Quest.shelfRung), and an item is
-- locked until that rung reaches its `unlockQuests`. It is one below the house's standing, because the
-- first errand a house is run for is its opener and that one buys the DOOR rather than a band of stock
-- -- see Quest.shelfRung for why. Passed as a bare number (not a player) so this module stays
-- player-free, which is also why the offset is the caller's to apply and not this function's.
--
-- `recipes` is an optional plain { itemId = tier } map (the player's consumable recipe levels):
-- a listed item is stocked at its tier, with `price` scaled to match, so buying it yields the
-- upgraded item.
--
-- Returns fresh tables, never the blueprints (which stay immutable).
-- `unlocked` is an optional bare set { disciplineId = true } of the player's unlocked disciplines
-- (Discipline.unlockedSet). A discipline item is stocked either way but stays `locked` -- greyed like a
-- quest-locked ware -- until its discipline is unlocked, because seeing the deeper cut you can earn is
-- the point, same as the quest ladder.
--
-- `levels` is the matching bare map { disciplineId = level } (Discipline.levelSet). The broad shelf
-- gates on QUEST COUNT; the deepest cut of a discipline gates on how far that discipline has actually
-- GROWN, via an optional `unlockLevel` on the item (default 0, so nothing gates on it until authored).
-- Two different questions -- "have you worked with this house" and "have you specialized" -- and the
-- shelf should not answer both with the same number.
-- `questsDone` may also be a FUNCTION of the item, returning the rung that item's own ladder has
-- reached. One shelf per house could take a single number because a house sold one class; the market
-- sells all seven (models/market.lua), and there each ware is gated on the level of ITS OWN class. A
-- bare number still works and means what it always meant, so every existing caller is untouched.
function Vendor.stock(vendorId, questsDone, recipes, unlocked, levels)
    local def = Vendor.defs[vendorId]
    if not def then return {} end
    local rungOf = questsDone
    if type(rungOf) ~= "function" then
        local fixed = questsDone or 0
        rungOf = function() return fixed end
    end

    local stock = {}
    for id, item in pairs(Item.defs) do
        if item.price and Vendor.sells(def, item) then
            local unlockQuests = item.unlockQuests or 0
            local level = (recipes and recipes[id]) or 0
            -- A discipline item is locked until its discipline is unlocked, on top of any quest gate --
            -- and, if it names an unlockLevel, until that discipline has grown that far.
            local disciplineLocked = item.discipline ~= nil and not (unlocked and unlocked[item.discipline])
            local unlockLevel = item.discipline and item.unlockLevel or nil
            if unlockLevel and ((levels and levels[item.discipline] or 0) < unlockLevel) then
                disciplineLocked = true
            end
            stock[#stock + 1] = {
                id = id,
                name = item.name,
                description = item.description,
                flavor = item.flavor,
                type = item.type,
                level = level,
                price = Vendor.priceFor(item.price, level),
                unlockQuests = unlockQuests,
                discipline = item.discipline,
                unlockLevel = unlockLevel,
                locked = (rungOf(item) < unlockQuests) or disciplineLocked,
            }
        end
    end

    table.sort(stock, function(a, b)
        if a.unlockQuests ~= b.unlockQuests then return a.unlockQuests < b.unlockQuests end
        if a.price ~= b.price then return a.price < b.price end
        return a.name < b.name
    end)
    return stock
end

-- Whether any of the item ids in `marked` (a bare set, i.e. player.newStock) sits on this vendor's
-- shelf. What the hub city's red dot on a shop reads: the reward panel names the wares once, and
-- without a mark on the door itself the player has to remember which house it said. Takes the bare
-- set rather than a player so this module stays player-free, like everything else here.
--
-- A ware that two shelves carry (a potion, resold at the Cafe) dots both doors, which is simply true:
-- it is new on both.
function Vendor.hasMarkedStock(vendorId, marked)
    local def = Vendor.defs[vendorId]
    if not (def and marked) then return false end
    for id in pairs(marked) do
        local item = Item.defs[id]
        if item and item.price and Vendor.sells(def, item) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Services: what a house does besides sell
-- ---------------------------------------------------------------------------
--
-- A shelf is the same verb at every door. Seven houses that all Buy and Sell means the city has two
-- verbs in it however many buildings get built, which is the whole of why the town stops changing once
-- the last door opens -- a new shop is only ever more rows. So a vendor may declare a SERVICE: one
-- thing only that house does, named on its own tab beside Buy and Sell.
--
-- One is authored (the Undercroft's Fence, below). The seam is what matters: a service is a data
-- field, so the other six are an authoring job rather than an engine one, and each house's
-- specialisation can be argued about in its own blueprint. Sketches, deliberately unbuilt --
-- the Crucible appraising a sealed find, the Arcanum reading an unknown discipline off a piece, the
-- Cafe standing a round -- are notes for that pass and not promises.
--
-- WHY THE UNDERCROFT GOT THE FIRST ONE. Greed's house, and the swap is greed's verb: nothing is
-- created, nothing is destroyed, and the fence takes a cut of the difference. It is also the service
-- an extraction game most obviously needs -- a run that pays out in gear produces duplicates by
-- construction, and until now the only thing to do with a second Iron Sword was sell it for half.

-- What the fence charges to turn one piece into another, as a share of the shelf price of the thing
-- handed over. Deliberately above the 50% a plain sell-back pays, because a swap is strictly better
-- than selling: it returns an ITEM rather than coin, at the grade you gave up, with no second trip to
-- the shelf and no waiting for a gate to open. Under 50% and selling would be strictly dominated,
-- which would make the Sell tab decorative at the one house that has both.
Vendor.SWAP_FEE = 0.6

-- The gold a swap costs, given the item being handed in. Rounded up, so no swap is ever free -- a
-- worthless trinket still costs a coin to launder, which is the fence's whole personality.
function Vendor.swapFee(item)
    if not item or not item.price then return nil end
    return math.max(1, math.ceil(Vendor.priceFor(item.price, item.level or 0) * Vendor.SWAP_FEE))
end

-- How far apart two prices may sit and still count as the same grade. A band rather than an exact
-- match because prices are derived from grade (docs/shelf.md) and land on arbitrary numbers: an exact
-- rule would make most items unswappable and the ones that were swappable a lookup table.
Vendor.SWAP_BAND = 0.35

-- What `vendorId` will hand over in exchange for `item`: every ware on its shelf of about the same
-- worth, minus the thing being traded in. The caller picks from the list, so the swap is a CHOICE and
-- not a roll -- a random return would make this a slot machine, and the player already has a slot
-- machine on the board in the shape of loot.
--
-- Locked stock is excluded outright, unlike the Buy list which shows it greyed: a shelf shows what you
-- are working toward, but a service that dangles a reward the fence cannot actually hand over is just
-- a worse error message. Takes the same bare `questsDone` / `recipes` / `unlocked` / `levels` the stock
-- call does, for the same player-free reason.
function Vendor.swapOffers(vendorId, item, questsDone, recipes, unlocked, levels)
    local def = Vendor.defs[vendorId]
    if not (def and def.service and def.service.id == "fence") then return {} end
    local worth = item and item.price and Vendor.priceFor(item.price, item.level or 0)
    if not worth or Item.isBound(item) then return {} end

    local lo, hi = worth * (1 - Vendor.SWAP_BAND), worth * (1 + Vendor.SWAP_BAND)
    local out = {}
    for _, entry in ipairs(Vendor.stock(vendorId, questsDone, recipes, unlocked, levels)) do
        if not entry.locked and entry.id ~= item.id
            and entry.price and entry.price >= lo and entry.price <= hi then
            out[#out + 1] = entry
        end
    end
    return out
end

-- What a vendor pays to buy `item` back: half its shelf price at the item's own level, rounded down --
-- so a refined consumable sells for more than a base one, matching what it cost. An item with no
-- `price` was never for sale and so can't be sold (returns 0) -- the Party screen refuses those
-- rather than giving them away for nothing. One place so the panel and its test agree on the rate.
function Vendor.sellValue(item)
    if not (item and item.price) then return 0 end
    if Item.isBound(item) then return 0 end -- a bound relic is never for sale, whatever price it carries
    return math.floor(Vendor.priceFor(item.price, item.level or 0) * 0.5)
end

return Vendor
