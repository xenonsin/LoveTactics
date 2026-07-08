-- Tests for consumable stacking: same-id merge into one inventory slot (Character.addItem),
-- the maxStack cap, and per-use decrement on a consuming ability (Combat.useItem). Pure
-- data/model layer, so it runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

-- A flat, all-walkable arena so a healing cast validates range (mirrors combat_spec's helper).
local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

-- The item in `char`'s inventory with the given id (nil if absent).
local function itemById(char, id)
    for _, it in ipairs(char.inventory) do
        if it.id == id then return it end
    end
    return nil
end

-- A mage spawn carrying a fresh 3-stack of potions in a single slot.
local function potionMage(x, y)
    local char = Character.instantiate("mage")
    char.inventory = { Item.instantiate("healing_potion", 3) }
    return { char = char, x = x, y = y }
end

return {
    {
        name = "only consumables are stackable",
        fn = function()
            assert(Item.isStackable(Item.instantiate("healing_potion")), "potion stacks")
            assert(not Item.isStackable(Item.instantiate("iron_sword")), "weapon does not stack")
            assert(Item.maxStack(Item.instantiate("iron_sword")) == 1, "non-stackable cap is 1")
        end,
    },
    {
        name = "a non-stackable item is pinned to quantity 1 even if seeded higher",
        fn = function()
            local sword = Item.instantiate("iron_sword", 5)
            assert(sword.quantity == 1, "weapon quantity must stay 1, got " .. tostring(sword.quantity))
        end,
    },
    {
        name = "instantiate clamps a seeded quantity to the stack cap",
        fn = function()
            local cap = Item.DEFAULT_MAX_STACK
            local big = Item.instantiate("healing_potion", cap + 4)
            assert(big.quantity == cap, "seeded quantity clamps to cap " .. cap)
            local zero = Item.instantiate("healing_potion", 0)
            assert(zero.quantity == 1, "quantity floors at 1")
        end,
    },
    {
        name = "adding a duplicate consumable merges into one stacked slot",
        fn = function()
            local c = Character.instantiate("knight")
            c.inventory = {}
            assert(Character.addItem(c, Item.instantiate("healing_potion")), "first potion added")
            assert(Character.addItem(c, Item.instantiate("healing_potion")), "second potion merged")
            assert(#c.inventory == 1, "both potions share one slot, got " .. #c.inventory)
            assert(itemById(c, "healing_potion").quantity == 2, "stack holds 2")
        end,
    },
    {
        name = "distinct items never merge",
        fn = function()
            local c = Character.instantiate("knight")
            c.inventory = {}
            Character.addItem(c, Item.instantiate("healing_potion"))
            Character.addItem(c, Item.instantiate("iron_sword"))
            assert(#c.inventory == 2, "different ids take separate slots")
        end,
    },
    {
        name = "a stack cannot merge past its cap; the overflow claims a new slot",
        fn = function()
            local c = Character.instantiate("knight")
            c.inventory = {}
            local cap = Item.DEFAULT_MAX_STACK
            assert(Character.addItem(c, Item.instantiate("healing_potion", cap)), "seed a full stack")
            assert(#c.inventory == 1 and c.inventory[1].quantity == cap, "one full stack")
            assert(Character.addItem(c, Item.instantiate("healing_potion")), "one more potion")
            assert(#c.inventory == 2, "the overflow starts a second slot")
            assert(c.inventory[2].quantity == 1, "overflow slot holds the leftover 1")
        end,
    },
    {
        name = "using a stacked consumable decrements it; the empty slot is kept and blocks reuse",
        fn = function()
            local c = Combat.new(arena(8, 8), { potionMage(3, 3) }, {})
            local mage = c.units[1]
            local potion = itemById(mage.char, "healing_potion")
            assert(potion.quantity == 3, "mage carries a stack of 3")
            mage.char.stats.health.current = 10 -- so the heal has somewhere to go

            assert(Combat.useItem(c, mage, potion, 3, 3), "self-heal use 1")
            assert(potion.quantity == 2, "stack drops to 2")
            assert(itemById(mage.char, "healing_potion") == potion, "slot survives")

            -- Drain the stack to empty (useItem ends the turn, so re-open one each time).
            c.turn = { unit = mage, moved = false, moveCost = 0 }
            assert(Combat.useItem(c, mage, potion, 3, 3), "self-heal use 2")
            c.turn = { unit = mage, moved = false, moveCost = 0 }
            assert(Combat.useItem(c, mage, potion, 3, 3), "self-heal use 3 (last)")

            -- Spent, but the slot is KEPT and activation is now blocked.
            assert(potion.quantity == 0, "stack is empty")
            assert(itemById(mage.char, "healing_potion") == potion, "the empty slot stays in inventory")
            assert(Combat.isDepleted(potion), "an empty stack reads as depleted")
            c.turn = { unit = mage, moved = false, moveCost = 0 }
            local ok, why = Combat.useItem(c, mage, potion, 3, 3)
            assert(not ok and why == "out of stock", "an empty stack can't be used")
        end,
    },
    {
        name = "restocking an empty stack merges into the kept slot and re-enables it",
        fn = function()
            local mage = Character.instantiate("mage")
            local slot = Item.instantiate("healing_potion")
            slot.quantity = 0 -- as if its last use was just spent (the kept, empty slot)
            mage.inventory = { slot }
            assert(Combat.isDepleted(slot), "the slot starts depleted")

            assert(Character.addItem(mage, Item.instantiate("healing_potion", 2)), "restock 2")
            assert(#mage.inventory == 1, "restock merges into the same slot")
            assert(slot.quantity == 2, "the kept slot refills to 2")
            assert(not Combat.isDepleted(slot), "the restocked slot is usable again")
        end,
    },
}
