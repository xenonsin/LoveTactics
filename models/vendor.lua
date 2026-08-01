-- Vendor logic. Blueprints live in data/vendors/<id>.lua: a class vendor's identity.
-- Vendors are decoupled from hub geometry (data/buildings/) so a quest can name a sponsor
-- without knowing where its building stands, and from the player (every gate here takes a
-- plain count of quests-completed, not a player) so models/player.lua and this module do
-- not form a require cycle.
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
-- not a re-home: the potion keeps its class, still grows and refines at the alchemist. See the stock
-- derivation below and docs/classes.md ("The general store").

local Registry = require("models.registry")
local Item = require("models.item")
local Discipline = require("models.discipline")

local Vendor = {}

Vendor.defs = Registry.load("data/vendors", "data.vendors")

function Vendor.get(id)
    return Vendor.defs[id]
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

-- The quest-count thresholds a shelf's four waves of stock open at. Items author their gate as
-- one of these numbers (`unlockQuests`), and the ability/recipe upgrade bench keys its level cap
-- off which wave a player's quest count has reached (Vendor.abilityLevelCap). One list so the
-- gear gates and the upgrade caps ramp together.
Vendor.TIERS = { 0, 3, 6, 10 }

-- Which wave (1..#TIERS) `questsDone` completed quests has reached: the number of thresholds it
-- has crossed. Used only for the upgrade-level cap; item stock gates on its own `unlockQuests`
-- directly, not on this.
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
function Vendor.stock(vendorId, questsDone, recipes, unlocked)
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
            -- A discipline item is locked until its discipline is unlocked, on top of any quest gate.
            local disciplineLocked = item.discipline ~= nil and not (unlocked and unlocked[item.discipline])
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

-- ---------------------------------------------------------------------------
-- Vendor upgrades
--
-- Weapons, armor and utility gear are forged at the Blacksmith; ABILITIES are honed here at their
-- class vendor (per instance -- you own one and improve it). CONSUMABLES are refined per-TYPE: a
-- vendor upgrades the recipe for a consumable it sells (Vendor.upgradeRecipe), and thereafter every
-- copy bought comes at that tier (see Vendor.stock's `recipes` and Player.recipeLevel). A vendor
-- upgrade is trained/brewed, not hammered, so it costs gold (no materials) and is gated by standing
-- rather than ore. Every path raises the same `level`, baked by Item.instantiate.
-- ---------------------------------------------------------------------------

-- Whether `vendorId` is the bench that upgrades `item` PER INSTANCE: an ability at its class vendor.
-- Consumables no longer take this path (they are refined per-type via Vendor.upgradeRecipe), so they
-- return false here. The single rule the shop's Upgrade list and the instance-upgrade action read.
function Vendor.canUpgradeHere(vendorId, item)
    local def = Vendor.defs[vendorId]
    if not def or not item or not Item.isUpgradable(item) then return false end
    -- The general store hones nothing per instance (it sells no abilities); guarding here keeps a
    -- classless ability from matching its nil class by accident. Consumables it sells still refine
    -- per-type via Vendor.upgradeRecipe, whose classless == classless match is intended.
    if def.general then return false end
    if item.type == "ability" then return Item.classOf(item) == def.class end
    return false
end

-- The highest ability level a player's quest count has earned the right to buy: the first wave
-- unlocks +1/+2, and each further wave one more, so the top wave (Vendor.tier 4) reaches the +5 cap.
-- A gate on the power curve that ramps with the same quest ladder the shelf itself opens on.
function Vendor.abilityLevelCap(questsDone)
    return math.min(Item.MAX_LEVEL, Vendor.tier(questsDone) + 1)
end

-- The cost to refine `item` one level for a player `questsDone` quests into this house: gold that
-- climbs with the level, plus whether that level is yet unlocked by their quest count. Returns nil
-- once the item is at Item.MAX_LEVEL.
--   { level = <target>, gold = <n>, locked = <bool> }
function Vendor.upgradeCost(item, questsDone)
    local target = (item.level or 0) + 1
    if target > Item.MAX_LEVEL then return nil end
    return {
        level = target,
        gold = 60 * target, -- +1 costs 60g, +5 costs 300g
        locked = target > Vendor.abilityLevelCap(questsDone),
    }
end

-- Perform a vendor upgrade for `player` at vendor `vendorId`: verify this is the right bench for the
-- item (Vendor.canUpgradeHere), that the next level is rank-unlocked, and that the gold is there;
-- spend it and return a FRESH instance at the new level, keeping its stack count (the caller swaps it
-- into the slot it came from). Returns the new item, or nil + a reason ("class" | "max level" |
-- "locked" | "gold"). ("class" here means "wrong bench" -- not this vendor's to upgrade.)
function Vendor.upgradeItem(player, vendorId, item, questsDone)
    local Player = require("models.player")
    if not Vendor.canUpgradeHere(vendorId, item) then return nil, "class" end
    local cost = Vendor.upgradeCost(item, questsDone)
    if not cost then return nil, "max level" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    Player.spendGold(player, cost.gold)
    return Item.instantiate(item.id, item.quantity, cost.level)
end

-- Back-compat aliases: the old ability-only names for the instance-upgrade path.
Vendor.abilityUpgradeCost = Vendor.upgradeCost
Vendor.upgradeAbility = Vendor.upgradeItem

-- ---------------------------------------------------------------------------
-- Consumable recipe upgrades (per-type)
-- ---------------------------------------------------------------------------

-- The cost to raise a consumable's recipe one tier from `level` for a player `questsDone` quests into
-- this house: gold that climbs with the tier (the same 60g-per-level curve the instance bench charges),
-- plus whether that tier is yet unlocked by their quest count. Returns nil once the recipe is at
-- Item.MAX_LEVEL.
--   { level = <target>, gold = <n>, locked = <bool> }
function Vendor.recipeUpgradeCost(level, questsDone)
    local target = (level or 0) + 1
    if target > Item.MAX_LEVEL then return nil end
    return {
        level = target,
        gold = 60 * target,
        locked = target > Vendor.abilityLevelCap(questsDone),
    }
end

-- Whether `vendorId` is the bench that REFINES consumable `item` (per-type, via Vendor.upgradeRecipe).
-- Only its brewer's own house refines a consumable -- its `class` vendor -- never a shop that merely
-- resells it: the Cafe carries potions but you hone the recipe at the alchemist, where it grows. So
-- the general store refines only genuinely classless consumables (of which there are none today). The
-- one rule the shop's Upgrade list and upgradeRecipe both read, so a listed row can always be bought.
function Vendor.canRefineHere(vendorId, item)
    local def = Vendor.defs[vendorId]
    if not def or not item or item.type ~= "consumable" or not Item.isUpgradable(item) then
        return false
    end
    return Item.classOf(item) == def.class
end

-- Refine the recipe for consumable `itemId` one tier at `vendorId`: verify this vendor is the bench
-- that refines it (Vendor.canRefineHere), that the next tier is rank-unlocked, and that the gold is
-- there; spend the gold and bump Player.recipeLevel. Returns the new tier, or nil + a reason ("class"
-- | "max level" | "locked" | "gold"). ("class" here means "not the bench that refines this".)
function Vendor.upgradeRecipe(player, vendorId, itemId, questsDone)
    local Player = require("models.player")
    local item = Item.defs[itemId] and Item.instantiate(itemId)
    if not Vendor.canRefineHere(vendorId, item) then
        return nil, "class"
    end
    local cost = Vendor.recipeUpgradeCost(Player.recipeLevel(player, itemId), questsDone)
    if not cost then return nil, "max level" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    Player.spendGold(player, cost.gold)
    Player.setRecipeLevel(player, itemId, cost.level)
    return cost.level
end

return Vendor
