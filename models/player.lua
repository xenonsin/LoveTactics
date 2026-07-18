-- Player logic. Defaults live in data/player.lua; `Player.new` builds the
-- mutable runtime state: the full roster of owned characters, the active
-- party (a capped subset of the roster), the stash of unequipped items, and the
-- progression state (gold, prestige, per-vendor reputation, completed quests).
--
-- `Player.active` is the one live player for the session. States must read it via
-- `Player.start()` rather than calling `Player.new()`, which discards all progress.

local Character = require("models.character")
local Growth = require("models.growth")
local Item = require("models.item")
local Save = require("models.save")
local Vendor = require("models.vendor")

local Player = {}

Player.defaults = require("data.player")

-- The current player. Set by Player.start; read by the hub and anything the hub hands
-- the player to. nil until a game is started or loaded.
Player.active = nil

-- Hard cap on the active party. The roster (owned characters) is unbounded;
-- only this many can be deployed at once.
Player.MAX_PARTY = 4

-- Base overworld fog-of-war vision radius (tiles seen around the player). A party
-- member carrying an item with a larger visionRadius (e.g. a torch) raises it.
Player.BASE_VISION = 2

-- Effective overworld vision radius for a player's active party: BASE_VISION raised
-- by the largest visionRadius of any item any party member is carrying. Kept here so
-- the "does the party have a torch" logic lives in one place; the item's field is the
-- single source of truth. A nil player (dev/test) returns the base.
function Player.visionRadius(player)
    local r = Player.BASE_VISION
    if player and player.party then
        for _, char in ipairs(player.party) do
            for _, item in ipairs(char.inventory or {}) do
                if item.visionRadius and item.visionRadius > r then r = item.visionRadius end
            end
        end
    end
    return r
end

-- Add a roster member to the active party, enforcing the party cap and rejecting a member who is
-- already deployed. Returns true on success, false if the party is full or already holds `char`.
function Player.addToParty(player, char)
    if #player.party >= Player.MAX_PARTY then
        return false
    end
    for _, member in ipairs(player.party) do
        if member == char then return false end
    end
    player.party[#player.party + 1] = char
    return true
end

-- The stash: every item the player owns that isn't sitting in some character's 3x3 grid. It has no
-- capacity at all -- a plain list -- so loot always has somewhere to go. A pickpocket whose own grid
-- is full pockets the stolen item straight in here (Combat.steal appends to combat.stash, which the
-- battle state points at this very table), and the Loadout panel moves items between it and a
-- character's grid.

-- Put `item` in the stash. A stackable item merges into an existing stack of the same id first, so
-- a run of stolen potions collapses into one entry rather than filling the list.
function Player.addToStash(player, item)
    player.stash = player.stash or {}
    if Item.isStackable(item) then
        for _, existing in ipairs(player.stash) do
            -- Same blueprint AND same upgrade level: a +1 potion is a different item than a +0 one, so
            -- a refined stack never absorbs (or is absorbed by) an unrefined one.
            if existing.id == item.id and (existing.level or 0) == (item.level or 0)
                and Item.isStackable(existing) then
                local room = Item.maxStack(existing) - existing.quantity
                if room > 0 then
                    local moved = math.min(room, item.quantity)
                    existing.quantity = existing.quantity + moved
                    item.quantity = item.quantity - moved
                    if item.quantity <= 0 then return true end -- fully absorbed
                end
            end
        end
    end
    player.stash[#player.stash + 1] = item
    return true
end

-- Instantiate `itemId` and put it in the stash. The one path by which the player is GIVEN an item
-- rather than buying it: a quest's `rewardItems` (models/quest.lua), which is how a general's relic
-- reaches the bag. Returns the instance, so a caller can name it in a reward summary.
function Player.grantItem(player, itemId)
    local item = Item.instantiate(itemId)
    Player.addToStash(player, item)
    return item
end

-- Pull the item at `index` out of the stash and hand it back (nil if there is nothing there).
function Player.takeFromStash(player, index)
    local stash = player.stash
    if not stash or not stash[index] then return nil end
    return table.remove(stash, index)
end

-- Remove a character from the active party (leaves them in the roster).
-- Returns true if the character was in the party.
function Player.removeFromParty(player, char)
    for i, member in ipairs(player.party) do
        if member == char then
            table.remove(player.party, i)
            return true
        end
    end
    return false
end

-- Gain a companion. The one path by which the player ADDS a character to the roster after the
-- starting party -- a prologue recruit (the knight sworn in the village, the gladiator bested on the
-- sand), and how a class line's main companion joins. Instantiates a fresh copy from the blueprint,
-- refuses a duplicate of one already owned, and levels the newcomer up to the company's current
-- prestige so a late recruit is not a level-1 liability (Player.syncLevels is idempotent for the
-- rest). Unless `opts.rosterOnly`, the recruit is also deployed to the active party when there is
-- room -- a full party leaves them on the bench, not un-recruited. Returns the instance, or nil if
-- the id was already on the roster. Persistence is the caller's call (like addToParty, unlike
-- Quest.complete), so a recruit granted mid-prologue is saved at the next real save point.
function Player.recruit(player, charId, opts)
    player.roster = player.roster or {}
    for _, char in ipairs(player.roster) do
        if char.id == charId then return nil end
    end
    local char = Character.instantiate(charId)
    player.roster[#player.roster + 1] = char
    Player.syncLevels(player)
    if not (opts and opts.rosterOnly) then Player.addToParty(player, char) end
    return char
end

-- Build fresh mutable player state for a new game. Party members reference the
-- same instances held in the roster, so a character is instantiated once.
function Player.new()
    local roster = {}
    local byId = {}
    for _, charId in ipairs(Player.defaults.startingRoster) do
        local char = Character.instantiate(charId)
        roster[#roster + 1] = char
        byId[charId] = char
    end

    local player = {
        gold = Player.defaults.gold,
        prestige = Player.defaults.prestige,
        -- The created avatar's body (1 or 2 -- which sprite set, not a gender) and typed name, both
        -- chosen at character creation (states/character_creation.lua); nil until then. The name is
        -- also copied onto the avatar instance (char.name), which is what the roster and dialogue
        -- read -- see Save.snapshotCharacter.
        body = nil,
        name = nil,
        roster = roster,
        party = {},
        stash = {}, -- unequipped items; unbounded (see Player.addToStash)
        reputation = {},      -- vendor id -> reputation points (see Player.addReputation)
        completedQuests = {}, -- quest id -> true; keeps finished quests off the board
        materials = {},       -- material id -> count; spent at the Blacksmith (see models/material.lua)
        recipes = {},         -- item id -> tier level; a consumable bought at its vendor comes at this level
    }

    for matId, count in pairs(Player.defaults.startingMaterials or {}) do
        player.materials[matId] = count
    end

    for _, charId in ipairs(Player.defaults.startingParty) do
        local char = byId[charId]
        assert(char, "startingParty id not in roster: " .. tostring(charId))
        assert(Player.addToParty(player, char), "startingParty exceeds MAX_PARTY of " .. Player.MAX_PARTY)
    end

    for _, itemId in ipairs(Player.defaults.startingStash or {}) do
        Player.addToStash(player, Item.instantiate(itemId))
    end

    return player
end

-- ---------------------------------------------------------------------------
-- Progression: gold, prestige, reputation
-- ---------------------------------------------------------------------------

function Player.addGold(player, amount)
    player.gold = player.gold + amount
end

-- Deduct `amount` if the player can afford it. Returns true on success, false (and
-- charges nothing) if they cannot -- callers branch on this rather than pre-checking.
function Player.spendGold(player, amount)
    if amount > player.gold then return false end
    player.gold = player.gold - amount
    return true
end

-- Grant prestige and level the company to match. Returns the advancement summary from Player.syncLevels
-- (the leveled members and their gains), which Quest.complete folds into its reward table.
function Player.addPrestige(player, amount)
    player.prestige = player.prestige + amount
    return Player.syncLevels(player)
end

-- Character level tracks the player's global prestige: raise every roster member to level == prestige,
-- resolving each pending level-up through models/growth (stat gains from the member's most-used class,
-- see docs). Idempotent -- a member already at the current prestige is left alone -- so it is safe to
-- call on every prestige change AND on load (a freshly recruited or migrated member catches up here).
-- Returns a summary list of the members that actually advanced, each { char, fromLevel, toLevel,
-- class, gains }, for the post-quest advancement overlay.
function Player.syncLevels(player)
    local summaries = {}
    for _, char in ipairs(player.roster or {}) do
        local summary = Growth.resolve(char, player.prestige)
        if summary then summaries[#summaries + 1] = summary end
    end
    return summaries
end

-- Reputation points with one vendor. Unknown vendors read as 0 rather than nil so
-- callers can do arithmetic without guarding.
function Player.reputation(player, vendorId)
    return (player.reputation or {})[vendorId] or 0
end

function Player.addReputation(player, vendorId, amount)
    player.reputation = player.reputation or {}
    player.reputation[vendorId] = Player.reputation(player, vendorId) + amount
end

-- The player's standing with a vendor as a rank index (see Vendor.rankFor). Rank gates
-- which of a vendor's items are on the shelf.
function Player.repRank(player, vendorId)
    return Vendor.rankFor(vendorId, Player.reputation(player, vendorId))
end

function Player.hasCompleted(player, questId)
    return (player.completedQuests or {})[questId] == true
end

-- ---------------------------------------------------------------------------
-- Materials (forging stock; see models/material.lua and the Blacksmith)
-- ---------------------------------------------------------------------------

-- How many of material `id` the player holds (0, not nil, for one never seen).
function Player.materialCount(player, id)
    return (player.materials or {})[id] or 0
end

function Player.addMaterial(player, id, amount)
    player.materials = player.materials or {}
    player.materials[id] = Player.materialCount(player, id) + (amount or 0)
end

-- Can the player pay a `{ [id] = count }` material cost in full?
function Player.canAffordMaterials(player, cost)
    for id, count in pairs(cost or {}) do
        if Player.materialCount(player, id) < count then return false end
    end
    return true
end

-- Deduct a `{ [id] = count }` material cost if it can be paid in full. Returns true on success,
-- false (charging nothing) otherwise -- callers branch on this rather than pre-checking.
function Player.spendMaterials(player, cost)
    if not Player.canAffordMaterials(player, cost) then return false end
    for id, count in pairs(cost or {}) do
        player.materials[id] = Player.materialCount(player, id) - count
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Recipes (consumable tiers; see the Upgrade mode in ui/panels/shop.lua)
-- ---------------------------------------------------------------------------

-- The tier a consumable id has been upgraded to (0, not nil, for one never refined). Every future
-- purchase of that item comes at this level, so the recipe is per-type progression, not per-instance.
function Player.recipeLevel(player, id)
    return (player.recipes or {})[id] or 0
end

function Player.setRecipeLevel(player, id, level)
    player.recipes = player.recipes or {}
    player.recipes[id] = level
end

-- ---------------------------------------------------------------------------
-- Rest
-- ---------------------------------------------------------------------------

-- Refill every roster member's resource stats to full. Health and mana carry across the
-- battles *within* a quest -- attrition over a run is the point -- but returning to the hub
-- rests the whole company. Called from states/hub.lua on entry, so a quest won or lost always
-- leaves the party whole, and this is why models/save.lua need not persist current resources.
function Player.restore(player)
    for _, char in ipairs(player.roster or {}) do
        for _, stat in ipairs(Character.RESOURCE_STATS) do
            local resource = char.stats[stat]
            if type(resource) == "table" then resource.current = resource.max end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Session lifecycle
-- ---------------------------------------------------------------------------

-- Establish `Player.active` and return it. With `fresh`, starts a new game and wipes any
-- save; otherwise resumes the save on disk, falling back to a new game when there is none
-- (or it is unreadable). Idempotent-ish: call it once per game start, not per state entry.
function Player.start(fresh)
    if fresh then
        Save.clear()
        Player.active = Player.new()
    else
        Player.active = Save.read() or Player.new()
    end
    -- Catch every roster member's level up to the current prestige. A no-op for a fresh game at
    -- prestige 1, but a loaded save whose stored levels lag (a schema migration, a recruit granted at
    -- higher prestige) is squared away here before anything reads the roster.
    Player.syncLevels(Player.active)
    return Player.active
end

-- Persist the active player. Called at the points progress is earned or spent -- quest
-- completion and vendor purchases -- so a crash costs at most one battle.
function Player.save()
    if Player.active then Save.write(Player.active) end
end

function Player.hasSave()
    return Save.exists()
end

return Player
