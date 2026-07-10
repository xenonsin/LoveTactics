-- Item logic. Blueprints live in data/items/<id>.lua (pure data, never
-- mutated); `Item.instantiate` builds a mutable runtime copy.

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Item = {}

Item.defs = Registry.load("data/items", "data.items")

-- The seven classes. An item's `class` decides which vendor stocks it (see models/vendor.lua);
-- it never gates who may equip the item. Anyone can carry anything -- class only says where
-- you buy it. That is what lets a player build a bespoke class by mixing shelves (a ninja is
-- mage gear on a rogue).
--
-- Deliberately its own field rather than an entry in `tags`: `tags` drives damage scaling and
-- armor `resist` lookups, so a shop taxonomy living there would be one typo away from armor
-- mitigating "rogue" damage.
--
-- One class per deadly sin: each vendor's quest line ends facing its own (see docs/story.md).
Item.CLASSES = {
    fighter = true,   -- wrath
    priest = true,    -- lust
    hunter = true,    -- gluttony
    knight = true,    -- sloth
    mage = true,      -- pride
    rogue = true,     -- greed
    alchemist = true, -- envy
}

-- nil for a universal item that no class vendor stocks.
function Item.classOf(item)
    return item and item.class
end

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

-- The highest upgrade level a forgeable item can reach (the five material tiers, +1..+5).
Item.MAX_LEVEL = 5

-- The per-level stat gain an upgrade grants, as { stat = perLevelAmount }. An item may name its own
-- balance knob with an `upgrade` field; otherwise a sensible default is derived from its kind -- a
-- weapon/ability sharpens the one Power its abilities scale by, armor thickens whichever defense it
-- leans on. Returns nil for an item that cannot be upgraded at all (a plain consumable/utility).
-- The single source of truth shared by Item.applyLevel (which bakes it) and the blacksmith/vendor UI.
function Item.upgradeSpec(item)
    if item.upgrade then return item.upgrade end
    if item.type == "armor" then
        if item.bonus and item.bonus.defense then return { defense = 2 } end
        if item.bonus and item.bonus.magicDefense then return { magicDefense = 2 } end
        return { defense = 2 }
    end
    if item.activeAbility and (item.type == "weapon" or item.type == "ability") then
        return { power = 2 } -- Power is "the one stat their abilities scale by"
    end
    return nil
end

-- Can this item be taken to the forge (or, for an ability, the class vendor) and leveled up?
function Item.isUpgradable(item)
    return item ~= nil and Item.upgradeSpec(item) ~= nil
end

-- Bake `item.level` levels of its upgrade into its scaling stat(s) and append " +n" to the display
-- name. Called once at instantiate; an upgrade re-instantiates from the blueprint at the new level
-- (see the blacksmith), so this never double-applies onto an already-leveled instance.
local function applyLevel(item)
    local lvl = item.level or 0
    if lvl <= 0 then return end
    local spec = Item.upgradeSpec(item)
    if spec then
        for stat, perLevel in pairs(spec) do
            local add = perLevel * lvl
            if stat == "power" then
                if item.activeAbility then
                    item.activeAbility.power = (item.activeAbility.power or 0) + add
                end
            else
                item.bonus = item.bonus or {}
                item.bonus[stat] = (item.bonus[stat] or 0) + add
            end
        end
    end
    -- "+n" rides on the name, so it shows everywhere the name does (grid, tooltip, combat log).
    item.name = (item.name or "?") .. " +" .. lvl
end

-- Build a fresh, mutable item instance from a blueprint id. `quantity` seeds a stack (clamped to
-- the item's maxStack) and defaults to 1; it is only meaningful for stackable (consumable) items.
-- `level` is the upgrade level (default 0), baked into the scaling stats and the " +n" name suffix.
function Item.instantiate(id, quantity, level)
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
        aura = deepCopy(def.aura),             -- adjacency: grants tags/statuses to neighboring casts
        bonus = deepCopy(def.bonus),           -- armor: flat stat bonuses folded in at setup
        resist = deepCopy(def.resist),         -- armor: tag -> flat damage reduction
        waitBehavior = deepCopy(def.waitBehavior), -- swaps this holder's Wait -> Focus / Defend
        moveBehavior = deepCopy(def.moveBehavior), -- swaps this holder's walk -> teleport (Blink)
        upgrade = deepCopy(def.upgrade),       -- per-level stat gain at the forge (nil = a default is derived)
        visionRadius = def.visionRadius,       -- overworld vision boost (e.g. torch); nil for most
        detectRadius = def.detectRadius,       -- combat: reveals traps within this radius (detectors)
        maxStack = def.maxStack,               -- stackable (consumable) items: per-slot cap override
        noSteal = def.noSteal,                 -- a pickpocket can never lift this (a beast's fangs)
        stealPriority = def.stealPriority,     -- a pickpocket takes the highest first (decoy bait)
        noCopy = def.noCopy,                   -- a summoned copy of the holder never carries this
        traits = deepCopy(def.traits),         -- combat reactions granted to whoever carries it
        class = def.class,                     -- which class vendor sells it; nil = sold by none
        price = def.price,                     -- vendor gold cost; nil means it is never sold
        repRank = def.repRank,                 -- vendor rank needed to unlock it (default 1)
        level = math.max(0, level or 0),       -- upgrade level; 0 = a base, un-forged item
    }

    -- Stack count: consumables carry a `quantity` (clamped to the item's cap); everything else is
    -- pinned to 1 so a non-stackable slot can never claim to hold more than one.
    if Item.isStackable(item) then
        item.quantity = math.max(1, math.min(quantity or 1, Item.maxStack(item)))
    else
        item.quantity = 1
    end

    applyLevel(item) -- fold the upgrade into the scaling stats and the display name
    return item
end

return Item
