-- Character (party member) logic. Blueprints live in data/characters/<id>.lua
-- with flat base stats; `Character.instantiate` builds a mutable runtime copy
-- where resource stats are split into { max, current }.

local Registry = require("models.registry")
local Item = require("models.item")
local Sprite = require("models.sprite")

local Character = {}

Character.MAX_INVENTORY = 9

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

-- Add an item to a character's inventory, enforcing the hard cap. A stackable (consumable) item
-- first merges into an existing same-id stack up to that stack's cap; only the leftover claims a
-- new slot. Returns true once the whole item is placed, false if the cap blocks the remainder
-- (any amount already merged into an existing stack stays merged).
function Character.addItem(char, item)
    if Item.isStackable(item) then
        for _, existing in ipairs(char.inventory) do
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
    if #char.inventory >= Character.MAX_INVENTORY then
        return false
    end
    char.inventory[#char.inventory + 1] = item
    return true
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
