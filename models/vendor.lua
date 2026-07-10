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

return Vendor
