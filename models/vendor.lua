-- Vendor logic. Blueprints live in data/vendors/<id>.lua: a class vendor's identity plus
-- its reputation ladder. Vendors are decoupled from hub geometry (data/buildings/) so a
-- quest can name a sponsor without knowing where its building stands, and from the player
-- (rank resolution takes a points number, not a player) so models/player.lua can depend on
-- this module without a require cycle.
--
-- Stock is *derived, not authored*: a vendor sells every priced item whose `class` matches its
-- own. Adding data/items/<slot>/<id>.lua with the right class puts it on that vendor's shelf.

local Registry = require("models.registry")
local Item = require("models.item")

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

-- Resolve reputation points to a rank index. `ranks` is an ascending list of thresholds
-- where ranks[1] is the entry rank, so the returned index is 1-based: rank 1 is the
-- lowest standing, #ranks the highest. An unknown vendor yields rank 1.
function Vendor.rankFor(vendorId, points)
    local def = Vendor.defs[vendorId]
    if not def then return 1 end

    local rank = 1
    for i, threshold in ipairs(def.ranks) do
        if points >= threshold then rank = i end
    end
    return rank
end

function Vendor.rankName(vendorId, rank)
    local def = Vendor.defs[vendorId]
    if not def then return "" end
    return def.rankNames[rank] or ""
end

-- Points still needed to reach the next rank, and that rank's index. Returns nil when the
-- player is already at the top -- the UI renders that as "max standing" rather than a bar.
function Vendor.nextRank(vendorId, points)
    local def = Vendor.defs[vendorId]
    if not def then return nil end

    local rank = Vendor.rankFor(vendorId, points)
    local nextThreshold = def.ranks[rank + 1]
    if not nextThreshold then return nil end
    return nextThreshold - points, rank + 1
end

-- Every item this vendor could ever sell, in shelf order (cheapest first). Rank-gated
-- items are included; `locked` marks the ones the player has not earned yet, so the shop
-- can show them greyed out -- seeing what reputation buys is the point of the ladder.
--
-- Returns fresh tables, never the blueprints (which stay immutable).
function Vendor.stock(vendorId, rank)
    local def = Vendor.defs[vendorId]
    if not def then return {} end
    rank = rank or 1

    local stock = {}
    for id, item in pairs(Item.defs) do
        if item.price and Item.classOf(item) == def.class then
            local repRank = item.repRank or 1
            stock[#stock + 1] = {
                id = id,
                name = item.name,
                description = item.description,
                type = item.type,
                price = item.price,
                repRank = repRank,
                locked = rank < repRank,
            }
        end
    end

    table.sort(stock, function(a, b)
        if a.repRank ~= b.repRank then return a.repRank < b.repRank end
        if a.price ~= b.price then return a.price < b.price end
        return a.name < b.name
    end)
    return stock
end

-- What a vendor pays to buy `item` back: half its shelf price, rounded down. An item with no
-- `price` was never for sale and so can't be sold (returns 0) -- the Party screen refuses those
-- rather than giving them away for nothing. One place so the panel and its test agree on the rate.
function Vendor.sellValue(item)
    return item.price and math.floor(item.price * 0.5) or 0
end

-- ---------------------------------------------------------------------------
-- Vendor upgrades
--
-- Weapons, armor and utility gear are forged at the Blacksmith; ABILITIES are honed here at their
-- class vendor, and CONSUMABLES are refined at the Alchemist (regardless of their own class -- one
-- bench brews them all). A vendor upgrade is trained/brewed, not hammered, so it costs gold (no
-- materials) and is gated by standing rather than ore. Every path raises the same `level`, baked by
-- Item.instantiate.
-- ---------------------------------------------------------------------------

-- Whether `vendorId` is the bench that upgrades `item`: an ability at its class vendor, a consumable
-- at the Alchemist. The single rule the shop's Upgrade list and the upgrade action both read.
function Vendor.canUpgradeHere(vendorId, item)
    local def = Vendor.defs[vendorId]
    if not def or not item or not Item.isUpgradable(item) then return false end
    if item.type == "consumable" then return vendorId == "alchemist" end
    if item.type == "ability" then return Item.classOf(item) == def.class end
    return false
end

-- The highest ability level a given rank has earned the right to buy: rank 1 unlocks +1/+2, and each
-- further rank one more, so Legend (rank 4) can reach the +5 cap. A gate on the power curve that
-- mirrors the reputation ladder the whole game runs on.
function Vendor.abilityLevelCap(rank)
    return math.min(Item.MAX_LEVEL, (rank or 1) + 1)
end

-- The cost to refine `item` one level at a vendor of `rank` standing: gold that climbs with the level,
-- plus whether that level is yet unlocked by the rank. Returns nil once the item is at Item.MAX_LEVEL.
--   { level = <target>, gold = <n>, locked = <bool> }
function Vendor.upgradeCost(item, rank)
    local target = (item.level or 0) + 1
    if target > Item.MAX_LEVEL then return nil end
    return {
        level = target,
        gold = 60 * target, -- +1 costs 60g, +5 costs 300g
        locked = target > Vendor.abilityLevelCap(rank),
    }
end

-- Perform a vendor upgrade for `player` at vendor `vendorId`: verify this is the right bench for the
-- item (Vendor.canUpgradeHere), that the next level is rank-unlocked, and that the gold is there;
-- spend it and return a FRESH instance at the new level, keeping its stack count (the caller swaps it
-- into the slot it came from). Returns the new item, or nil + a reason ("class" | "max level" |
-- "locked" | "gold"). ("class" here means "wrong bench" -- not this vendor's to upgrade.)
function Vendor.upgradeItem(player, vendorId, item)
    local Player = require("models.player")
    if not Vendor.canUpgradeHere(vendorId, item) then return nil, "class" end
    local rank = Vendor.rankFor(vendorId, Player.reputation(player, vendorId))
    local cost = Vendor.upgradeCost(item, rank)
    if not cost then return nil, "max level" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    Player.spendGold(player, cost.gold)
    return Item.instantiate(item.id, item.quantity, cost.level)
end

-- Back-compat aliases: the old ability-only names, now that the bench upgrades consumables too.
Vendor.abilityUpgradeCost = Vendor.upgradeCost
Vendor.upgradeAbility = Vendor.upgradeItem

return Vendor
