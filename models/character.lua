-- Character (party member) logic. Blueprints live in data/characters/<id>.lua
-- with flat base stats; `Character.instantiate` builds a mutable runtime copy
-- where resource stats are split into { max, current }.

local Registry = require("models.registry")
local Item = require("models.item")
local Sprite = require("models.sprite")

local Character = {}

Character.MAX_INVENTORY = 9

-- The inventory is a fixed 3x3 grid (nine cells). Items are stored in `char.inventory` as a
-- sparse 1-based array where any cell may be nil (an empty grid slot). Cell index maps to grid
-- position row-major: col = (i-1) % COLS, row = floor((i-1) / COLS) -- the same mapping the combat
-- panel uses to lay the slots out (see ui/combat_panel.lua). Adjacency (used by adjacency-effect
-- items) includes the four diagonals. Because the array can hold gaps, never use `#char.inventory`
-- to size or scan it -- iterate 1..MAX_INVENTORY (or use Character.eachItem) instead.
Character.COLS, Character.ROWS = 3, 3

-- The fallback unarmed weapon id, attached to every instance as `char.unarmed` (a hidden
-- weapon that never sits in `inventory`). A blueprint may override it with an `unarmed`
-- field naming a different item (e.g. a beast's natural bite). See data/items/unarmed.lua.
Character.DEFAULT_UNARMED = "unarmed"

-- Stats that deplete during play. On instantiation these become
-- { max = base, current = base }; every other stat is copied as a flat number.
-- Keeping the list here is the single source of truth for "which stats are
-- resources".
Character.RESOURCE_STATS = { "health", "mana", "stamina" }

local function isResourceStat(key)
    for _, name in ipairs(Character.RESOURCE_STATS) do
        if name == key then return true end
    end
    return false
end

Character.defs = Registry.load("data/characters", "data.characters")

-- The first empty grid cell (1..MAX_INVENTORY), or nil if the grid is full.
function Character.firstEmptySlot(char)
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] == nil then return i end
    end
    return nil
end

-- Number of occupied cells (the array may be sparse, so `#` is unreliable).
function Character.itemCount(char)
    local n = 0
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] ~= nil then n = n + 1 end
    end
    return n
end

-- The occupied items in cell order (gaps skipped) -- for callers that just need "the items".
function Character.eachItem(char)
    local list = {}
    for i = 1, Character.MAX_INVENTORY do
        local item = char.inventory[i]
        if item ~= nil then list[#list + 1] = item end
    end
    return list
end

-- The 1-based cell holding `item` (identity match), or nil if it isn't in the grid (e.g. the
-- hidden unarmed weapon, which never sits in the inventory).
function Character.slotIndex(char, item)
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] == item then return i end
    end
    return nil
end

-- Grid cells adjacent to `index` (1..MAX_INVENTORY), diagonals included: every cell whose row and
-- column are within 1 of `index`'s, excluding `index` itself. Corners have 3 neighbors, edges 5,
-- the center 8. Returns a list of indices.
function Character.adjacentIndices(index)
    local col = (index - 1) % Character.COLS
    local row = math.floor((index - 1) / Character.COLS)
    local out = {}
    for dr = -1, 1 do
        for dc = -1, 1 do
            if not (dr == 0 and dc == 0) then
                local r, c = row + dr, col + dc
                if r >= 0 and r < Character.ROWS and c >= 0 and c < Character.COLS then
                    out[#out + 1] = r * Character.COLS + c + 1
                end
            end
        end
    end
    return out
end

-- The (non-nil) items in the cells adjacent to `index`.
function Character.adjacentItems(char, index)
    local out = {}
    for _, i in ipairs(Character.adjacentIndices(index)) do
        local item = char.inventory[i]
        if item ~= nil then out[#out + 1] = item end
    end
    return out
end

-- Add an item to a character's inventory, enforcing the hard cap. A stackable (consumable) item
-- first merges into an existing same-id stack up to that stack's cap; only the leftover claims the
-- first empty grid cell. Returns true once the whole item is placed, false if the grid is full and
-- blocks the remainder (any amount already merged into an existing stack stays merged).
function Character.addItem(char, item)
    if Item.isStackable(item) then
        for _, existing in ipairs(Character.eachItem(char)) do
            if existing.id == item.id and Item.isStackable(existing) then
                local room = Item.maxStack(existing) - existing.quantity
                if room > 0 then
                    local moved = math.min(room, item.quantity)
                    existing.quantity = existing.quantity + moved
                    item.quantity = item.quantity - moved
                    if item.quantity <= 0 then return true end -- fully absorbed into the stack
                end
            end
        end
    end
    local slot = Character.firstEmptySlot(char)
    if not slot then
        return false
    end
    char.inventory[slot] = item
    return true
end

-- Remove `item` (identity match) from the grid, emptying its cell. Returns true if it was there.
-- The counterpart to Character.addItem, used when an item leaves a character entirely -- stolen by
-- a pickpocket, or moved out to the player's stash.
function Character.removeItem(char, item)
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] == item then
            char.inventory[i] = nil
            return true
        end
    end
    return false
end

-- Build a fresh, mutable character instance from a blueprint id.
function Character.instantiate(id)
    local def = Character.defs[id]
    assert(def, "unknown character id: " .. tostring(id))

    local stats = {}
    for key, value in pairs(def.stats) do
        if isResourceStat(key) then
            stats[key] = { max = value, current = value }
        else
            stats[key] = value
        end
    end

    local char = {
        id = id,
        name = def.name,
        sprite = Sprite.load(def.sprite),
        stats = stats,
        inventory = {},
        -- Hidden fallback weapon (never in inventory, never shown in the item grid). Sourced
        -- from the blueprint's `unarmed` id or the generic default.
        unarmed = Item.instantiate(def.unarmed or Character.DEFAULT_UNARMED),
    }

    for _, itemId in ipairs(def.startingItems or {}) do
        Character.addItem(char, Item.instantiate(itemId))
    end

    return char
end

return Character
