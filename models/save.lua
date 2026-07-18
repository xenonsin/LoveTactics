-- Save/load. Serializes player progress to a Lua source file in love.filesystem's
-- save directory (named by `t.identity` in conf.lua).
--
-- The schema is deliberately *lean*: it stores blueprint ids, not live instances.
-- Loading re-hydrates through Character.instantiate / Item.instantiate and then
-- overlays the saved state, so blueprints stay the source of truth and a content
-- edit (rebalancing a stat, renaming an item) flows into existing saves instead of
-- corrupting them.
--
-- What is NOT saved: current health/mana/stamina. There is nothing worth saving -- returning to
-- the hub calls `Player.restore`, which refills them. Attrition lasts a quest, not a campaign,
-- so a loaded party is always whole.
--
-- Headless-safe: love.filesystem only, no love.graphics at require time.

local Character = require("models.character")
local Item = require("models.item")
local Material = require("models.material")

local Save = {}

Save.FILE = "save.lua"

-- Bump when the *schema* changes shape (not when game content changes). A save whose
-- version doesn't match is discarded rather than half-read into a broken player.
-- v2: the created avatar -- player.gender + a per-character display name (char.name) override.
Save.VERSION = 2

-- ---------------------------------------------------------------------------
-- Serialization
-- ---------------------------------------------------------------------------

local function keyOrder(a, b)
    if type(a) == type(b) then return tostring(a) < tostring(b) end
    return type(a) == "number" -- numeric keys first
end

-- Encode a value as a Lua literal. Keys are emitted in `[k] = v` form throughout so
-- sparse arrays (a 3x3 inventory with gaps) survive the round trip intact, and sorted
-- so a save file diffs cleanly. Only data types are supported -- functions, userdata,
-- and love objects must never reach here, which is why the snapshot below stores ids.
local function encode(value, indent)
    local t = type(value)
    if t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t ~= "table" then
        error("save: cannot serialize a " .. t)
    end

    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, keyOrder)
    if #keys == 0 then return "{}" end

    local pad = string.rep(" ", indent + 4)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = pad .. "[" .. encode(k, 0) .. "] = " .. encode(value[k], indent + 4)
    end
    return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. string.rep(" ", indent) .. "}"
end

-- Load a serialized table back. The save file is a self-contained Lua module (it carries
-- its own `return`), so it loads as-is. The chunk runs in an empty environment: a save is
-- executable Lua, and gets no access to globals even if hand-edited.
local function decode(source)
    local loader = loadstring or load
    local chunk = loader(source, "save")
    if not chunk then return nil end
    if setfenv then setfenv(chunk, {}) end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then return nil end
    return result
end

-- ---------------------------------------------------------------------------
-- Snapshot: live player -> plain data
-- ---------------------------------------------------------------------------

local function snapshotItem(item)
    -- Upgrade level rides along so a forged "+n" item survives a save; omitted when 0 to keep base
    -- gear diffing clean. Rehydrated through Item.instantiate, which re-bakes the level from the
    -- blueprint, so a rebalanced upgrade curve flows into old saves like every other content edit.
    local snap = { id = item.id, quantity = item.quantity or 1 }
    if item.level and item.level > 0 then snap.level = item.level end
    return snap
end

-- A character's grid is sparse (cells 1..9, any may be nil), so it is snapshotted as a
-- keyed map of cell -> item rather than a list, preserving exact placement. Adjacency
-- auras depend on where an item sits, so placement is gameplay state, not cosmetics.
local function snapshotCharacter(char)
    local inventory = {}
    for cell = 1, Character.MAX_INVENTORY do
        local item = char.inventory[cell]
        if item then inventory[cell] = snapshotItem(item) end
    end

    local snap = { id = char.id, inventory = inventory }

    -- A custom display name overrides the blueprint's -- the created avatar wears the name the
    -- player typed at the arena, while every other character shows its blueprint name. Stored only
    -- when it differs, so an ordinary recruit diffs clean.
    local bp = Character.defs[char.id]
    if char.name and char.name ~= (bp and bp.name) then snap.name = char.name end

    -- The player's pinned default action (a grid cell index, set in the Loadout screen). Optional --
    -- omitted when unset, so a character that never chose one diffs clean and loads back to the auto
    -- pick. See Combat.defaultAction.
    if char.defaultActionSlot then snap.defaultActionSlot = char.defaultActionSlot end

    -- Progression (models/growth.lua). Level defaults back to 1 on load, so omit it while unleveled to
    -- keep an early-game save diffing clean; the same for an empty tally / no accumulated growth.
    if char.level and char.level > 1 then snap.level = char.level end

    local classUse = {}
    for class, count in pairs(char.classUse or {}) do
        if count and count > 0 then classUse[class] = count end
    end
    if next(classUse) then snap.classUse = classUse end

    local growth = {}
    for stat, amount in pairs(char.growth or {}) do
        if amount and amount ~= 0 then growth[stat] = amount end
    end
    if next(growth) then snap.growth = growth end

    return snap
end

function Save.snapshot(player)
    local roster, indexOf = {}, {}
    for i, char in ipairs(player.roster) do
        roster[i] = snapshotCharacter(char)
        indexOf[char] = i
    end

    -- Party members are the *same instances* held in the roster, so store indices to
    -- keep that identity across a save/load round trip rather than duplicating them.
    local party = {}
    for _, char in ipairs(player.party) do
        party[#party + 1] = assert(indexOf[char], "party member missing from roster: " .. tostring(char.id))
    end

    local stash = {}
    for i, item in ipairs(player.stash or {}) do stash[i] = snapshotItem(item) end

    local reputation = {}
    for vendorId, points in pairs(player.reputation or {}) do reputation[vendorId] = points end

    local completedQuests = {}
    for questId, done in pairs(player.completedQuests or {}) do
        if done then completedQuests[questId] = true end
    end

    local materials = {}
    for id, count in pairs(player.materials or {}) do
        if count and count > 0 then materials[id] = count end
    end

    -- Consumable recipe tiers. Omit level 0 (the default) so an un-refined game diffs clean.
    local recipes = {}
    for id, level in pairs(player.recipes or {}) do
        if level and level > 0 then recipes[id] = level end
    end

    return {
        version = Save.VERSION,
        gold = player.gold,
        prestige = player.prestige,
        gender = player.gender, -- the created avatar's gender ("F"/"M"); nil before character creation
        reputation = reputation,
        completedQuests = completedQuests,
        materials = materials,
        recipes = recipes,
        roster = roster,
        party = party,
        stash = stash,
    }
end

-- ---------------------------------------------------------------------------
-- Restore: plain data -> live player
-- ---------------------------------------------------------------------------

-- An id that vanished from data/ (a removed item, a renamed character) must not crash a
-- load. Unknown ids are dropped and the rest of the save survives.
local function known(defs, id)
    return id ~= nil and defs[id] ~= nil
end

local function restoreCharacter(snap)
    -- Pass the saved progression through instantiate, which re-bakes the accumulated growth onto the
    -- base stats (max for resource pools) so the character loads at its full leveled power.
    local char = Character.instantiate(snap.id, {
        level = snap.level,
        classUse = snap.classUse,
        growth = snap.growth,
    })

    -- instantiate() seeds the grid from the blueprint's startingItems; the save owns the
    -- grid, so clear it and lay the saved items back into their exact cells.
    char.inventory = {}
    for cell, itemSnap in pairs(snap.inventory or {}) do
        if known(Item.defs, itemSnap.id) then
            char.inventory[tonumber(cell)] = Item.instantiate(itemSnap.id, itemSnap.quantity, itemSnap.level)
        end
    end
    -- Re-seat any bound signature relics in their authored cells. A current save already has them (at
    -- their upgraded level, preserved); a save predating a relic gets it restored. See Character.ensureBoundItems.
    Character.ensureBoundItems(char)
    -- nil on a save that never pinned one = the auto pick. Fall back to the legacy defaultWeaponSlot
    -- key so a save from before the default-weapon -> default-action rename keeps its pin.
    char.defaultActionSlot = snap.defaultActionSlot or snap.defaultWeaponSlot
    -- A saved custom display name (the created avatar's) overrides the blueprint name instantiate set.
    if snap.name then char.name = snap.name end
    return char
end

-- Rebuild mutable player state from a snapshot. Returns nil if the snapshot is unusable
-- (wrong version, malformed), letting the caller fall back to a fresh game.
function Save.restore(snap)
    if type(snap) ~= "table" or snap.version ~= Save.VERSION then return nil end

    local roster = {}
    for _, charSnap in ipairs(snap.roster or {}) do
        if known(Character.defs, charSnap.id) then
            roster[#roster + 1] = restoreCharacter(charSnap)
        end
    end
    if #roster == 0 then return nil end -- nothing left to play with

    local party = {}
    for _, index in ipairs(snap.party or {}) do
        local char = roster[index]
        if char then party[#party + 1] = char end
    end

    local stash = {}
    for _, itemSnap in ipairs(snap.stash or {}) do
        if known(Item.defs, itemSnap.id) then
            stash[#stash + 1] = Item.instantiate(itemSnap.id, itemSnap.quantity, itemSnap.level)
        end
    end

    local reputation = {}
    for vendorId, points in pairs(snap.reputation or {}) do reputation[vendorId] = points end

    local completedQuests = {}
    for questId in pairs(snap.completedQuests or {}) do completedQuests[questId] = true end

    -- Materials are dropped if the id no longer exists in data/ (a removed tier), like every other id.
    local materials = {}
    for id, count in pairs(snap.materials or {}) do
        if known(Material.defs, id) and count and count > 0 then materials[id] = count end
    end

    -- Recipe tiers for items that still exist in data/ (a removed consumable drops its tier).
    local recipes = {}
    for id, level in pairs(snap.recipes or {}) do
        if known(Item.defs, id) and level and level > 0 then recipes[id] = level end
    end

    return {
        gold = snap.gold or 0,
        prestige = snap.prestige or 1,
        gender = snap.gender, -- nil for a save made before character creation set it
        reputation = reputation,
        completedQuests = completedQuests,
        materials = materials,
        recipes = recipes,
        roster = roster,
        party = party,
        stash = stash,
    }
end

-- ---------------------------------------------------------------------------
-- Disk
-- ---------------------------------------------------------------------------

function Save.exists()
    return love.filesystem.getInfo(Save.FILE) ~= nil
end

-- Returns true on success, or false plus a message.
function Save.write(player)
    local source = "-- LoveTactics save. Generated file; edit at your own risk.\nreturn "
        .. encode(Save.snapshot(player), 0) .. "\n"
    return love.filesystem.write(Save.FILE, source)
end

-- The restored player, or nil if there is no save (or it is unreadable).
function Save.read()
    if not Save.exists() then return nil end
    local source = love.filesystem.read(Save.FILE)
    if not source then return nil end
    local snap = decode(source)
    if not snap then return nil end
    return Save.restore(snap)
end

function Save.clear()
    if Save.exists() then love.filesystem.remove(Save.FILE) end
end

return Save
