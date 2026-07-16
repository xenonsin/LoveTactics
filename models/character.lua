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

-- A blueprint's `startingItems` is a POSITIONAL 3x3 grid (row-major, matching the grid the player
-- sees): cell i holds startingItems[i]. An entry is an item id string, a { id, count } stack (for a
-- consumable), or false/nil for an empty cell. A designer arranges the loadout by cell -- including
-- the character's bound signature relic, which is just an item marked `bound` sitting in whatever cell
-- (conventionally the center, cell 5) they place it. There is no reserved slot: the lock lives on the
-- item (Item.isBound), not the cell, so the same technique works for any item in any cell.
local function layoutId(entry)
    if type(entry) == "string" then return entry end
    if type(entry) == "table" then return entry.id or entry[1] end
    return nil
end
local function layoutCount(entry)
    if type(entry) == "table" then return entry.n or entry[2] end
    return nil
end

-- The fallback unarmed weapon id, attached to every instance as `char.unarmed` (a hidden
-- weapon that never sits in `inventory`). A blueprint may override it with an `unarmed`
-- field naming a different item (e.g. a beast's natural bite). See data/items/unarmed.lua.
--
-- A blueprint may also set `unarmed = false` for a body with NO natural weapon whatsoever, leaving
-- `char.unarmed` nil: a thing that can be moved around the board but cannot strike anything, ever.
-- That is what a Pig is (data/characters/pig.lua) -- polymorph takes away what you can DO, and with
-- no items and no fists there is nothing left to do. Every reader of `char.unarmed` already treats it
-- as optional (Combat.defaultWeapon documents a possible nil; the enemy AI appends it only
-- `if unit.char.unarmed`), so this needs no special casing anywhere else.
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

-- Reconcile the BOUND items in `char`'s blueprint loadout into a LOADED character's grid. A bound item
-- (a signature relic) is nailed to the cell the blueprint authored it in -- it can never be moved -- so
-- on load we make sure each one is present in exactly that cell. A current save already has it there
-- (at its upgraded level, which is preserved); a save that predates the item gets it seeded. Anything a
-- stale save left in a bound cell is displaced to the first free cell. Idempotent. Generalizes to any
-- number of bound items in any cells, not just one center relic.
function Character.ensureBoundItems(char)
    local def = Character.defs[char.id]
    if not (def and def.startingItems) then return end
    for cell = 1, Character.MAX_INVENTORY do
        local id = layoutId(def.startingItems[cell])
        if id and Item.defs[id] and Item.defs[id].bound then
            local current = char.inventory[cell]
            if not (current and current.id == id) then
                -- Recover the relic from wherever a stale save left it (preserving its level), else mint
                -- a base one; move any non-relic occupant of the cell aside; then seat the relic.
                local relic
                for i = 1, Character.MAX_INVENTORY do
                    local it = char.inventory[i]
                    if it and it.id == id then relic = it; char.inventory[i] = nil; break end
                end
                relic = relic or Item.instantiate(id)
                if char.inventory[cell] then
                    local occupant = char.inventory[cell]
                    char.inventory[cell] = nil
                    Character.addItem(char, occupant)
                end
                char.inventory[cell] = relic
            end
        end
    end
end

-- Add a class-usage cast to a character's running tally. Fired from Combat.useItem whenever a party
-- member resolves an action with a class-tagged item (a spell, a weapon strike, a thrown consumable).
-- The most-used class drives stat growth on level-up (see models/growth.lua).
function Character.recordUse(char, class)
    if not class then return end
    char.classUse = char.classUse or {}
    char.classUse[class] = (char.classUse[class] or 0) + 1
end

-- Build a fresh, mutable character instance from a blueprint id. `progress` (optional) restores the
-- saved level-up state: { level, classUse, growth }. When present, the accumulated growth deltas are
-- re-baked into the stats here (max for resource stats), so a loaded character comes back at its full
-- leveled power without replaying its history. A new character passes nil -> level 1, no growth.
function Character.instantiate(id, progress)
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

    -- Re-bake accumulated level-up growth onto the base stats (resource growth raises the pool's max).
    local growth = (progress and progress.growth) or {}
    for stat, amount in pairs(growth) do
        local live = stats[stat]
        if type(live) == "table" and isResourceStat(stat) then
            live.max = live.max + amount
            live.current = live.max
        elseif type(live) == "number" then
            stats[stat] = live + amount
        end
    end

    local char = {
        id = id,
        name = def.name,
        sprite = Sprite.load(def.sprite),
        -- Large VN portrait for conversations (ui/dialogue.lua); optional -- Sprite.load is tolerant,
        -- so a character with no `portrait` (or missing art) falls back to the letter-box placeholder.
        portrait = Sprite.load(def.portrait),
        stats = stats,
        -- Progression state (models/growth.lua): innate growth class (fallback/tie-break), the level
        -- (tracks player prestige), the per-class cast tally, and the accumulated stat growth.
        class = def.class,
        -- A general/boss blueprint sets `boss = true`; carried through so an ability can refuse to work
        -- on one (Coup de Grace won't execute a boss, Charm won't turn it). Nil for an ordinary unit.
        boss = def.boss,
        level = (progress and progress.level) or 1,
        classUse = (progress and progress.classUse) or {},
        growth = (progress and progress.growth) or {},
        inventory = {},
        -- Hidden fallback weapon (never in inventory, never shown in the item grid). Sourced
        -- from the blueprint's `unarmed` id or the generic default; explicitly `false` for a body
        -- with no natural weapon at all (see Character.DEFAULT_UNARMED), which leaves this nil.
        unarmed = def.unarmed ~= false and Item.instantiate(def.unarmed or Character.DEFAULT_UNARMED) or nil,
    }

    -- Starting loadout, authored as a positional 3x3 grid: cell i holds startingItems[i] (an item id,
    -- a { id, count } stack, or false/nil for empty). Placed by cell, not merged -- the designer's
    -- layout is exactly what the character starts with. A character's innate reaction is no longer a
    -- property here; it rides on a bound signature item placed in the grid like any other (its trait
    -- reaches the unit via models/trait.lua, its lock via Item.isBound).
    local layout = def.startingItems or {}
    for cell = 1, Character.MAX_INVENTORY do
        local id = layoutId(layout[cell])
        if id then
            char.inventory[cell] = Item.instantiate(id, layoutCount(layout[cell]))
        end
    end

    -- Authored default action (optional): the blueprint names an item id its bearer starts with
    -- pinned as the default action (Combat.defaultAction / the Loadout star), so a freshly recruited
    -- character already has a sensible go-to action rather than the bare auto-pick. Resolved to the
    -- grid cell now holding that item; a missing/unplaced id just leaves the auto-pick in force.
    if def.defaultAction then
        for cell = 1, Character.MAX_INVENTORY do
            local it = char.inventory[cell]
            if it and it.id == def.defaultAction then
                char.defaultActionSlot = cell
                break
            end
        end
    end

    return char
end

return Character
