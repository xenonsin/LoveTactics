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

-- The fifteen weapon families. A weapon carries exactly one of these among its `tags`, and that tag
-- names the base mechanics the weapon inherits -- an axe cleaves, a hammer stuns, a dagger bleeds.
-- See docs/weapons.md for the contract each family owes.
--
-- Unlike `class` above this DOES live in `tags`, because a family is a real property of the swing:
-- it sits beside the damage school (physical/magical), the hit tag (slash/pierce/impact), and the
-- reach tag (melee/ranged) that scaling and armor `resist` already read. All of them are peers in one
-- flat list -- membership is what identifies the family, never position, so re-ordering an item's
-- tags can never change what it is.
Item.ARCHETYPES = {
    shield = true, staff = true, greatsword = true, axe = true,
    mace = true, dagger = true, sword = true, hammer = true,
    wand = true, spear = true, bow = true, longbow = true, unarmed = true,
    -- The censer: a focus that carries its ground with it (`incense`, see Combat.layIncense). The one
    -- family whose weapon is not the strike -- a banner is ground that stays and a trail is ground you
    -- leave behind, and this is ground that walks. See docs/weapons.md.
    censer = true,
    -- The fifteenth, and the only one no player ever shops for: a creature's own body -- a wolf's
    -- fangs, a zombie's claws, an elemental's burning hands. Granted by a blueprint's startingItems,
    -- never sold and never stolen (`noSteal`), and owing no shared mechanic beyond that, since what a
    -- monster's body does is the monster's business. It is a family so that every weapon in the game
    -- answers "which family?" -- an unfamilied weapon is an authoring slip, not a natural weapon.
    --
    -- Distinct from `unarmed`, which is the PLAYER's bare fist: that one is a single hidden instance
    -- (char.unarmed) and the fist charms find it by identity, not by tag (see combat.lua's
    -- unarmedDamageBonus). Tagging a creature's fists `unarmed` would not feed them those bonuses --
    -- it would only make them undisarmable by accident.
    natural = true,
}

-- The archetype tag on `item`, or nil if it declares none (an ability, a charm, a consumable -- none
-- of which belong to a weapon family). A weapon carrying two archetype tags is authoring error: this
-- returns whichever comes first, and tests/weapon_spec.lua fails the build over it.
function Item.archetype(item)
    if not item then return nil end
    for _, tag in ipairs(item.tags or {}) do
        if Item.ARCHETYPES[tag] then return tag end
    end
    return nil
end

-- An ability's declared resource costs, ALWAYS as a list of `{ stat, amount }` -- empty for a free
-- ability. `activeAbility.cost` may be authored either way:
--
--   cost = { stat = "stamina", amount = 8 }                     -- one pool (the common case)
--   cost = { { stat = "mana", amount = 4 },                     -- several pools, all paid together
--            { stat = "stamina", amount = 5 } }
--
-- The single form is sugar, not a second shape: everything downstream of here prices, gates, spends
-- and draws a LIST, so a weapon that draws on two pools can never be affordable in one place and
-- unaffordable in another. Distinguished by looking for `stat` on the table itself -- a list never
-- carries one. Returns a fresh list, so callers may sort or scale it in place.
--
-- Costs are per-pool and never merged: two entries naming the same stat would be an authoring slip,
-- and are left alone rather than quietly summed, so the mistake stays visible in the tooltip.
function Item.costs(ab)
    return Item.costList(ab and ab.cost)
end

-- The same normalization for a BARE cost value rather than an ability's -- a trait def's own `cost`,
-- or the price Trait.answerCost quotes for a swing. Both shapes reach the pay path from there too,
-- so they are unpacked by the same three lines and there is exactly one place that knows what a
-- cost may look like.
function Item.costList(cost)
    if not cost then return {} end
    if cost.stat then return { { stat = cost.stat, amount = cost.amount } } end
    local out = {}
    for i, c in ipairs(cost) do out[i] = { stat = c.stat, amount = c.amount } end
    return out
end

-- Does `ab` draw on `stat`? The membership question the sorcery/silence gates ask ("is any part of
-- this paid for in mana?"), asked once so a dual-cost spell counts as sorcery on the strength of its
-- mana half rather than on whichever pool happened to be authored first.
function Item.costsStat(ab, stat)
    for _, c in ipairs(Item.costs(ab)) do
        if c.stat == stat then return true end
    end
    return false
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
-- a draught's `restore`, or a scroll's `reviveHealth`. Exactly one is authored per ability. Each entry
-- is { key, label } -- the label heads the tooltip/shop row. A summon or a placed hazard/trap declares
-- no such magnitude: it scales off the item's upgrade level (fx.level) instead, so it has no headline.
local ABILITY_MAGNITUDES = {
    { "damage", "Damage" },
    { "healing", "Healing" },
    { "restore", "Restore" },
    { "reviveHealth", "Revive" },
    -- A ward's magnitude is COVERAGE: how many blows it swallows before it is spent (the barriers,
    -- which pass it to the status as its `magnitude`). The odd one out in kind but not in shape --
    -- an ability that negates a hit outright has no number to make bigger, so the only axis an
    -- upgrade can move it along is how many hits it does that to.
    { "hits", "Hits" },
}

-- An ability's SECONDARY magnitudes: authored, tuned per level exactly like the headline above, but
-- never the headline itself. A spell whose payload is not its damage needs somewhere to put the
-- payload's number, and deriving it from the damage (which is what Jolt used to do) welds two stats
-- that want different curves together -- a Jolt is deliberately a feeble hit selling TEMPO, so the
-- delay it buys has no business being pinned to how little it hurts.
--
-- Excluded from ABILITY_MAGNITUDES on purpose: `primaryStat` leads the tooltip with the number that
-- says what the item IS, and for an offensive spell that is still its damage.
local ABILITY_SECONDARY_MAGNITUDES = {
    "stun", -- ticks a Jolt adds to its target's initiative (data/items/ability/ability_jolt.lua)
}

-- The `waitBehavior` payoffs that scale with the granting item's level -- what the swapped Wait pays
-- out: defend's brace (`defense`) and the share it lends adjacent allies (`covers`), focus's mana,
-- overwatch's per-shot stamina.
local WAIT_BEHAVIOR_MAGNITUDES = { "defense", "mana", "stamina", "covers" }

-- Every place an item carries a scaling magnitude, as get/set pairs, so one walk resolves them all at
-- instantiate. This is the definition of "a derived magnitude": an ability's damage/healing/etc.,
-- armor's stat bonuses and resists, a resource ceiling, a wait-swap's payoff, and an aura's
-- amount/range/status magnitude.
local function eachMagnitude(item, fn)
    local ab = item.activeAbility
    if ab then
        for _, m in ipairs(ABILITY_MAGNITUDES) do
            local key = m[1]
            if ab[key] ~= nil then fn(ab[key], function(x) ab[key] = x end) end
        end
        for _, key in ipairs(ABILITY_SECONDARY_MAGNITUDES) do
            if ab[key] ~= nil then fn(ab[key], function(x) ab[key] = x end) end
        end
        -- A directional blast footprint can widen with the forge: `shape` and `length` (and the
        -- centred shapes' `width`/`radius`) may each be authored as a per-level list, resolved here
        -- to this level's entry exactly as a numeric magnitude is. That lets a weapon open from a
        -- straight line into a cone as it is forged (data/items/weapon/weapon_first_motion.lua), and
        -- keeps the preview footprint and the effect's fx.aoeUnits reading one baked-in shape.
        local aoe = ab.aoe
        if aoe then
            for _, key in ipairs({ "shape", "length", "width", "radius" }) do
                if aoe[key] ~= nil then fn(aoe[key], function(x) aoe[key] = x end) end
            end
        end
    end
    if item.bonus then for k, v in pairs(item.bonus) do fn(v, function(x) item.bonus[k] = x end) end end
    if item.resist then for k, v in pairs(item.resist) do fn(v, function(x) item.resist[k] = x end) end end
    if item.maxBonus then for k, v in pairs(item.maxBonus) do fn(v, function(x) item.maxBonus[k] = x end) end end
    if item.unarmedBonus then for k, v in pairs(item.unarmedBonus) do fn(v, function(x) item.unarmedBonus[k] = x end) end end
    -- A wait-swap's payoff scales with its item's level too, so a forged shield braces harder and a
    -- forged staff meditates deeper: `defense` (Combat.defend feeds it to the Defending status as its
    -- magnitude), `mana` (Combat.focus restores it), `stamina` (Combat.overwatch's per-shot budget).
    -- Deliberately NOT `speed`: that is what the swap costs the timeline, not what it pays out, and an
    -- upgrade should never buy back tempo.
    local wb = item.waitBehavior
    if wb then
        for _, key in ipairs(WAIT_BEHAVIOR_MAGNITUDES) do
            if wb[key] ~= nil then fn(wb[key], function(x) wb[key] = x end) end
        end
    end
    -- A censer's smoke thickens with its level: `amount` rides in as the granted status's magnitude,
    -- exactly as a wait-swap's payoff does. Deliberately NOT `radius` -- that is the censer's reach,
    -- and an upgrade buys a stronger blessing, never a wider one. Same line the wait swap draws above.
    local inc = item.incense
    if inc and inc.amount ~= nil then fn(inc.amount, function(x) inc.amount = x end) end
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
        description = def.description,         -- what it does: mechanical, one sentence (docs/item-text.md)
        flavor = def.flavor,                   -- what it means: the story line, italic at the tooltip's foot
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
        trail = deepCopy(def.trail),           -- { hazard, duration } | { trap }: ground left behind every tile walked
        incense = deepCopy(def.incense),       -- { hazard, radius, amount }: ground that follows the bearer (a censer)
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
