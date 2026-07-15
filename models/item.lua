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

-- Is this item bound to its holder? A bound item (a character's signature relic) can never be moved
-- within the grid, stowed, given away, sold, or stolen -- only upgraded in place. It's a reusable
-- flag: any item can set `bound = true` and every mutation path (the grid editor, the party panel,
-- the vendor, combat theft) refuses to move it. The one thing that reads it, so they all agree.
function Item.isBound(item)
    return item ~= nil and item.bound == true
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

-- The highest upgrade level a forgeable item can reach. Every item carries a `level` from 0 (base) to
-- MAX_LEVEL, and that level -- not any derived rating -- is the single number every stat scales with.
Item.MAX_LEVEL = 10

local function titleCase(s)
    return (tostring(s):gsub("^%l", string.upper))
end

-- Resolve one authored magnitude to its value at `level`. A TUNED magnitude is a list over the levels
-- 0..MAX_LEVEL (element 1 = level 0, element 2 = level 1, ...); a level past the authored length
-- clamps to the last entry, so a short list holds flat once it runs out. A plain NUMBER is a flat
-- magnitude that does not scale -- the same at every level (the form most items still carry). This is
-- the single rule the whole model reads: "what is this magnitude worth at this upgrade level?"
local function resolveLevel(v, level)
    if type(v) ~= "table" then return v end
    local idx = math.max(1, math.min(#v, (level or 0) + 1))
    return v[idx]
end
Item.resolveLevel = resolveLevel

-- An ability names its magnitude for what it does: a weapon/spell's `damage`, a potion's `healing`,
-- a draught's `restore`, a scroll's `reviveHealth`, or a summon's `summonPower`. Exactly one is
-- authored per ability. Each entry is { key, label } -- the label heads the tooltip/shop row.
local ABILITY_MAGNITUDES = {
    { "damage", "Damage" },
    { "healing", "Healing" },
    { "restore", "Restore" },
    { "reviveHealth", "Revive" },
    { "summonPower", "Power" },
}

-- Every place an item carries a scaling magnitude, as get/set pairs, so one walk resolves them all at
-- instantiate. This is the definition of "a derived magnitude": an ability's damage/healing/etc.,
-- armor's stat bonuses and resists, a resource ceiling, and an aura's amount/range/status magnitude.
local function eachMagnitude(item, fn)
    local ab = item.activeAbility
    if ab then
        for _, m in ipairs(ABILITY_MAGNITUDES) do
            local key = m[1]
            if ab[key] ~= nil then fn(ab[key], function(x) ab[key] = x end) end
        end
    end
    if item.bonus then for k, v in pairs(item.bonus) do fn(v, function(x) item.bonus[k] = x end) end end
    if item.resist then for k, v in pairs(item.resist) do fn(v, function(x) item.resist[k] = x end) end end
    if item.maxBonus then for k, v in pairs(item.maxBonus) do fn(v, function(x) item.maxBonus[k] = x end) end end
    if item.unarmedBonus then for k, v in pairs(item.unarmedBonus) do fn(v, function(x) item.unarmedBonus[k] = x end) end end
    local aura = item.aura
    if aura then
        if aura.amountBonus ~= nil then fn(aura.amountBonus, function(x) aura.amountBonus = x end) end
        if aura.rangeBonus ~= nil then fn(aura.rangeBonus, function(x) aura.rangeBonus = x end) end
        local st = aura.status
        if st and st.opts and st.opts.magnitude ~= nil then
            fn(st.opts.magnitude, function(x) st.opts.magnitude = x end)
        end
    end
end

-- The item's primary stat -- the one the tooltip/shop headline leads with -- as `value, label, key`.
-- The priority reads off the stat that defines the item: an ability's own magnitude (damage / healing
-- / etc.), then armor's defense / magic defense, then the largest of any remaining bonus / resource /
-- aura magnitude. Resolved at the item's level, so it quotes the current (leveled) number. `key` is the
-- raw bonus key (or nil) so a caller can suppress that same row elsewhere. nil when the item grants no
-- magnitude at all.
function Item.primaryStat(item)
    if not item then return nil end
    local lvl = item.level or 0
    local ab = item.activeAbility
    if ab then
        for _, m in ipairs(ABILITY_MAGNITUDES) do
            if ab[m[1]] ~= nil then return resolveLevel(ab[m[1]], lvl), m[2], nil end
        end
    end
    if item.bonus then
        if item.bonus.defense ~= nil then return resolveLevel(item.bonus.defense, lvl), "Defense", "defense" end
        if item.bonus.magicDefense ~= nil then return resolveLevel(item.bonus.magicDefense, lvl), "Magic Defense", "magicDefense" end
    end
    local best, bestLabel, bestKey
    local function consider(v, label, key)
        v = resolveLevel(v, lvl)
        if v and v ~= 0 and (not best or math.abs(v) > math.abs(best)) then best, bestLabel, bestKey = v, label, key end
    end
    if item.bonus then for k, v in pairs(item.bonus) do consider(v, titleCase(k), k) end end
    if item.maxBonus then for k, v in pairs(item.maxBonus) do consider(v, "Max " .. titleCase(k)) end end
    if item.unarmedBonus then for k, v in pairs(item.unarmedBonus) do consider(v, "Fist " .. titleCase(k)) end end
    local aura = item.aura
    if aura then
        if aura.status and aura.status.opts then consider(aura.status.opts.magnitude, titleCase(aura.status.id or "effect")) end
        consider(aura.amountBonus, "Aura Amount")
        consider(aura.rangeBonus, "Aura Range")
    end
    if best then return best, bestLabel, bestKey end
    return nil
end

-- Whether an item can be leveled up at all: it can, as long as it has a magnitude to scale. WHERE it
-- is leveled is a routing question the forge/vendor answer (weapons/armor/utility at the smithy,
-- abilities at their class vendor, consumables at the alchemist); this only asks whether there is any
-- stat for a level to move. An item with no magnitude (a plain torch) can't be upgraded.
function Item.isUpgradable(item)
    return item ~= nil and Item.primaryStat(item) ~= nil
end

-- Bake `item.level` into every magnitude (resolving each per-level list to this level's tuned value)
-- and append " +n" to the display name. Called once at instantiate; an upgrade re-instantiates from
-- the blueprint at the new level (see the blacksmith), so this never compounds onto a leveled instance.
local function applyLevel(item)
    local lvl = math.max(0, math.min(item.level or 0, Item.MAX_LEVEL))
    item.level = lvl
    eachMagnitude(item, function(v, set) set(resolveLevel(v, lvl)) end)
    if lvl > 0 then
        -- "+n" rides on the name, so it shows everywhere the name does (grid, tooltip, combat log).
        item.name = (item.name or "?") .. " +" .. lvl
    end
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
        activeAbility = deepCopy(def.activeAbility), -- { target, range, speed, cost, effect }
        aura = deepCopy(def.aura),             -- adjacency: grants tags/statuses to neighboring casts
        bonus = deepCopy(def.bonus),           -- armor: flat stat bonuses folded in at setup
        resist = deepCopy(def.resist),         -- armor: tag -> flat damage reduction
        unarmedBonus = deepCopy(def.unarmedBonus), -- "fist" charms: buff the bare-handed strike
        maxBonus = deepCopy(def.maxBonus),     -- resource passives: raise a max health/stamina/mana ceiling
        waitBehavior = deepCopy(def.waitBehavior), -- swaps this holder's Wait -> Focus / Defend
        moveBehavior = deepCopy(def.moveBehavior), -- swaps this holder's walk -> teleport (Blink)
        visionRadius = def.visionRadius,       -- overworld vision boost (e.g. torch); nil for most
        detectRadius = def.detectRadius,       -- combat: reveals traps within this radius (detectors)
        maxStack = def.maxStack,               -- stackable (consumable) items: per-slot cap override
        noSteal = def.noSteal,                 -- a pickpocket can never lift this (a beast's fangs)
        hands = def.hands,                     -- weapons: 1 (default, nil) or 2 -- what Dual Wield reads
        stealPriority = def.stealPriority,     -- a pickpocket takes the highest first (decoy bait)
        noCopy = def.noCopy,                   -- a summoned copy of the holder never carries this
        bound = def.bound,                     -- bound to its holder: never moved, stowed, sold, or stolen (a signature relic)
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
