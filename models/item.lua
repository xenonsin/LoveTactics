-- Item logic. Blueprints live in data/items/<id>.lua (pure data, never
-- mutated); `Item.instantiate` builds a mutable runtime copy.

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Item = {}

Item.defs = Registry.load("data/items", "data.items")

-- Build a fresh, mutable item instance from a blueprint id.
function Item.instantiate(id)
    local def = Item.defs[id]
    assert(def, "unknown item id: " .. tostring(id))

    return {
        id = id,
        name = def.name,
        description = def.description,
        sprite = Sprite.load(def.sprite),
    }
end

return Item
