-- Item logic. Blueprints live in data/items/<id>.lua (pure data, never
-- mutated); `Item.instantiate` builds a mutable runtime copy.

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Item = {}

Item.defs = Registry.load("data/items", "data.items")

-- Stacking: only consumables occupy a single inventory slot as a countable stack (a bundle of
-- health potions with a finite number of uses). Every other type is one-per-slot. A stack can
-- grow up to `maxStack` (the blueprint may override Item.DEFAULT_MAX_STACK), so "limited uses"
-- is just the running `quantity` on the instance. Character.addItem merges same-id stacks and
-- Combat.useItem decrements a stack on a consuming use, removing the slot only at 0.
Item.DEFAULT_MAX_STACK = 9

-- Is this item (instance or def) allowed to stack? Consumables only.
function Item.isStackable(item)
    return item ~= nil and item.type == "consumable"
end

-- The maximum count a stack of this item may hold (1 for anything non-stackable).
function Item.maxStack(item)
    if not Item.isStackable(item) then return 1 end
    return item.maxStack or Item.DEFAULT_MAX_STACK
end

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

-- Build a fresh, mutable item instance from a blueprint id. `quantity` seeds a stack (clamped to
-- the item's maxStack) and defaults to 1; it is only meaningful for stackable (consumable) items.
function Item.instantiate(id, quantity)
    local def = Item.defs[id]
    assert(def, "unknown item id: " .. tostring(id))

    local item = {
        id = id,
        name = def.name,
        description = def.description,
        sprite = Sprite.load(def.sprite),
        type = def.type,                       -- weapon | armor | consumable | ability | utility
        tags = deepCopy(def.tags),             -- descriptive tags: scaling + armor mitigation
        activeAbility = deepCopy(def.activeAbility), -- { name, target, range, speed, cost, effect }
        bonus = deepCopy(def.bonus),           -- armor: flat stat bonuses folded in at setup
        resist = deepCopy(def.resist),         -- armor: tag -> flat damage reduction
        visionRadius = def.visionRadius,       -- overworld vision boost (e.g. torch); nil for most
        detectRadius = def.detectRadius,       -- combat: reveals traps within this radius (detectors)
        maxStack = def.maxStack,               -- stackable (consumable) items: per-slot cap override
    }

    -- Stack count: consumables carry a `quantity` (clamped to the item's cap); everything else is
    -- pinned to 1 so a non-stackable slot can never claim to hold more than one.
    if Item.isStackable(item) then
        item.quantity = math.max(1, math.min(quantity or 1, Item.maxStack(item)))
    else
        item.quantity = 1
    end

    return item
end

return Item
