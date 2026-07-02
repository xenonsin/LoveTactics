-- Character (party member) logic. Blueprints live in data/characters/<id>.lua
-- with flat base stats; `Character.instantiate` builds a mutable runtime copy
-- where resource stats are split into { max, current }.

local Registry = require("models.registry")
local Item = require("models.item")
local Sprite = require("models.sprite")

local Character = {}

Character.MAX_INVENTORY = 9

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

-- Append an item to a character's inventory, enforcing the hard cap.
-- Returns true on success, false if the inventory is already full.
function Character.addItem(char, item)
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
    }

    for _, itemId in ipairs(def.startingItems or {}) do
        Character.addItem(char, Item.instantiate(itemId))
    end

    return char
end

return Character
