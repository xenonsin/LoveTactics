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
-- to look. What the Forge still borrows from here is Vendor.tier: standing with a house is the ceiling
-- on how far its gear forges.
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
-- One vendor is different: a `general = true` store (the Cafe) is the shelf for CLASSLESS priced
-- goods -- mundane traveler's supplies no sin claims (a torch, the boots of speed). A priced item
-- with no class used to be unbuyable dead data; the general store is where it now belongs. It ALSO
-- resells any item bearing one of its `stockTags` (the Cafe carries every `potion`, whichever house
-- brews it) -- so a class item can appear on two shelves, its own and the Cafe's. That is a resale,
-- not a re-home: the potion keeps its class, which is what its forge bill and ceiling read. See the
-- stock derivation below and docs/classes.md ("The general store").

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

-- The quest-count thresholds a house's standing climbs through. Items no longer author their gate as
-- one of these -- `unlockQuests` is a per-quest number now, so a shelf moves every quest rather than
-- in four clumps. What survives is the STANDING ladder: Forge.ceilingFor reads it to decide how far up
-- a class item may be forged, so the house you keep running is the house whose gear goes deepest.
Vendor.TIERS = { 0, 3, 6, 10 }

-- Which wave (1..#TIERS) `questsDone` completed quests has reached: the number of thresholds it
-- has crossed. Used only for the Forge's class-item ceiling; item stock gates on its own
-- `unlockQuests` directly, not on this.
function Vendor.tier(questsDone)
    questsDone = questsDone or 0
    local tier = 1
    for i, threshold in ipairs(Vendor.TIERS) do
        if questsDone >= threshold then tier = i end
    end
    return tier
end

-- The shelf price of a base item scaled to `level`: +50% of the base per tier, rounded. A consumable
-- refined to a higher recipe tier (Player.recipeLevel) is stocked and sold at this raised price. A nil
-- base (an item that was never for sale) stays nil. One place so shelf price and sell value agree.
function Vendor.priceFor(base, level)
    return base and math.floor(base * (1 + 0.5 * (level or 0)) + 0.5)
end

-- Whether `def` (a vendor blueprint) stocks `item`. A class vendor sells its own class; a general
-- store sells the classless goods AND resells anything bearing one of its `stockTags` (the Cafe
-- carries every `potion`, whatever its class). One rule, so the shop, the sell-back, and the refine
-- gate all agree on what a shelf holds. Takes the def rather than an id so stock can call it in a loop.
function Vendor.sells(def, item)
    if not def or not item then return false end
    if def.general then
        if Item.classOf(item) == nil then return true end
        for _, want in ipairs(def.stockTags or {}) do
            for _, tag in ipairs(item.tags or {}) do
                if tag == want then return true end
            end
        end
        return false
    end
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
-- `questsDone` is the count of this vendor's quests the player has finished (Quest.sponsorProgress).
-- An item is locked until that count reaches its `unlockQuests`. Passed as a bare number (not a
-- player) so this module stays player-free.
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
function Vendor.stock(vendorId, questsDone, recipes, unlocked, levels)
    local def = Vendor.defs[vendorId]
    if not def then return {} end
    questsDone = questsDone or 0

    local stock = {}
    for id, item in pairs(Item.defs) do
        if item.price and Vendor.sells(def, item) then
            -- The general store runs no quest line, so it gates nothing on quests: an item that needs
            -- ten quests at its own house (a Panacea) is simply on the shelf here. Class vendors honour
            -- the item's own unlockQuests.
            local unlockQuests = def.general and 0 or (item.unlockQuests or 0)
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
                locked = (questsDone < unlockQuests) or disciplineLocked,
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

-- What a vendor pays to buy `item` back: half its shelf price at the item's own level, rounded down --
-- so a refined consumable sells for more than a base one, matching what it cost. An item with no
-- `price` was never for sale and so can't be sold (returns 0) -- the Party screen refuses those
-- rather than giving them away for nothing. One place so the panel and its test agree on the rate.
function Vendor.sellValue(item)
    if not item.price then return 0 end
    if Item.isBound(item) then return 0 end -- a bound relic is never for sale, whatever price it carries
    return math.floor(Vendor.priceFor(item.price, item.level or 0) * 0.5)
end

return Vendor
