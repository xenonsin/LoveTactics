-- Item logic. Blueprints live in data/items/<id>.lua (pure data, never
-- mutated); `Item.instantiate` builds a mutable runtime copy.

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Item = {}

Item.defs = Registry.load("data/items", "data.items")

-- Recursively copy a blueprint value so a runtime instance never mutates the immutable
-- def. Tables are copied; every non-table value (numbers, strings, and crucially the
-- ability `effect` *function*) is carried by reference -- functions aren't mutated, so
-- sharing the reference is correct (and the only option).
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = deepCopy(v) end
    return out
end

-- Build a fresh, mutable item instance from a blueprint id.
function Item.instantiate(id)
    local def = Item.defs[id]
    assert(def, "unknown item id: " .. tostring(id))

    return {
        id = id,
        name = def.name,
        description = def.description,
        sprite = Sprite.load(def.sprite),
        type = def.type,                       -- weapon | armor | consumable | gem | utility
        tags = deepCopy(def.tags),             -- descriptive tags: scaling + armor mitigation
        activeAbility = deepCopy(def.activeAbility), -- { name, target, range, speed, cost, effect }
        bonus = deepCopy(def.bonus),           -- armor: flat stat bonuses folded in at setup
        resist = deepCopy(def.resist),         -- armor: tag -> flat damage reduction
        visionRadius = def.visionRadius,       -- overworld vision boost (e.g. torch); nil for most
    }
end

return Item
