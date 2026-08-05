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
Character.DEFAULT_UNARMED = "weapon_unarmed"

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

-- A blueprint's `footprint` into a normalized { w, h }. Accepts { w = 2, h = 2 } (the authored form),
-- a bare integer N (shorthand for an N×N square), or nil/absent -> 1×1. Dimensions are floored to at
-- least 1, so a malformed blueprint degrades to a single tile rather than a zero-size body.
-- Public so a caller holding only the BLUEPRINT can ask how much board a body would cover without
-- instantiating one -- states/battle.lua sizes a telegraphed arrival's marker that way.
function Character.normalizeFootprint(fp)
    if type(fp) == "number" then
        local n = math.max(1, math.floor(fp))
        return { w = n, h = n }
    end
    if type(fp) == "table" then
        return { w = math.max(1, math.floor(fp.w or 1)), h = math.max(1, math.floor(fp.h or 1)) }
    end
    return { w = 1, h = 1 }
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

-- Bank `amount` technique under `key` on this character. Fired from Combat.useItem whenever a party
-- member resolves an action with a class- or discipline-tagged item. `key` is a class id OR a
-- discipline id, whichever the item votes for (Discipline.growthClasses).
--
-- ONE LEDGER, read three ways. This used to be three counters -- a career tally, a since-level tally,
-- and a separate discipline wallet -- on the reasoning that "a vote and a bank cannot share a counter",
-- since spending the bank would have destroyed the vote. That objection was only ever about SPENDING,
-- and the fix is the one FFT's JP uses: keep what was EARNED monotonic and track what was SPENT beside
-- it, rather than decrementing one number and losing the history in it.
--
--   `technique`         earned, per key, never decremented. What this character has BEEN, across its
--                       whole career -- so it drives the displayed title (Growth.dominantClass) -- and
--                       simultaneously the numerator of everything below.
--   `techniqueSpent`    what the Forge has billed (Discipline.spendTechnique). Available to spend is
--                       `technique - techniqueSpent`; forging can never move the two readings above it.
--   `techniqueAtLevel`  a SNAPSHOT of `technique` taken when the last level landed, so the level-up
--                       reads the delta since (models/growth.lua). A checkpoint, not a counter -- which
--                       is why one action now writes one table instead of two.
--
-- Reading the level-up off a DELTA rather than off the career total is what keeps changing your mind
-- affordable: against the cumulative figure a veteran taking up a new discipline would have to out-cast
-- its entire history before one level followed, so the longer a character lived the more it cost to
-- develop -- precisely backwards.
--
-- PER CHARACTER, because that is what makes specializing pay. A pooled roster-wide total would make
-- putting one cheap discipline item on all four bodies accrue four times as fast, so spreading would
-- strictly dominate committing -- the exact inversion the old max-across-roster read of
-- Discipline.level existed to prevent. The bill spends from whichever body holds the most
-- (Discipline.techniqueHolder), so gear stays free to circulate while the pressure stays on the body.
--
-- No `Discipline` require here: this module stays dependency-light, and only the caller
-- (Combat.useItem) needs to know a key is a real discipline. It is stored as handed over.
function Character.recordTechnique(char, key, amount)
    if not (char and key) or (amount or 0) <= 0 then return 0 end
    char.technique = char.technique or {}
    char.technique[key] = (char.technique[key] or 0) + amount
    return amount
end

-- What `char` has earned under `key` since its last level-up -- the reading models/growth.lua weighs
-- one level's growth by. Never negative: `technique` only rises and the snapshot is only ever taken
-- from it.
function Character.techniqueSinceLevel(char, key)
    if not (char and key) then return 0 end
    local earned = (char.technique or {})[key] or 0
    return math.max(0, earned - ((char.techniqueAtLevel or {})[key] or 0))
end

-- What `char` has left to spend under `key`: earned minus what the Forge has already billed.
function Character.techniqueAvailable(char, key)
    if not (char and key) then return 0 end
    local earned = (char.technique or {})[key] or 0
    return math.max(0, earned - ((char.techniqueSpent or {})[key] or 0))
end

-- Build a fresh, mutable character instance from a blueprint id. `progress` (optional) restores the
-- saved level-up state: { level, growth, technique, ... }. When present, the accumulated growth deltas are
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
        -- The art PATHS the two fields above were loaded from. Sprite.load hands back an image object
        -- (or a placeholder) that no longer knows where it came from, so a tool that has only the
        -- runtime character -- the debug editor writing a blueprint back to data/characters/ -- would
        -- otherwise have no way to name the art again.
        spritePath = def.sprite,
        portraitPath = def.portrait,
        stats = stats,
        -- Progression state (models/growth.lua): innate growth class (fallback/tie-break), the level
        -- (tracks player prestige), the per-class cast tally, and the accumulated stat growth.
        class = def.class,
        -- What KIND of body this is: "humanoid" | "beast" | "demon" | "undead" | "construct" |
        -- "elemental" | "object". Declared by every blueprint rather than guessed -- tools/char_compose
        -- used to infer it from words in the id, which read every wolf and boar as a humanoid because
        -- nothing in "character_boar" says otherwise. It is also the line the bestiary's outfitting rule
        -- is drawn along (docs/bestiary.md): a HUMANOID carries priced, lootable, shareable gear off a
        -- shelf and names the class that shelf belongs to; every other kind carries natural weapons
        -- only -- unpriced, `noSteal`, and never a discipline item. A wolf is not a Beastmaster; a wolf
        -- is what a Beastmaster has.
        kind = def.kind,
        -- Which RUNG of the ladder this body sits on (docs/bestiary.md): 1 chaff · 2 line · 3 elite ·
        -- 4 boss, or 0 for a body that is not on the ladder at all -- a prop, an escortee, or a shape
        -- worn by Wild Shape. A DECLARED LABEL, never a multiplier: nothing derives a stat from it.
        -- What it buys is encounters composed as budgets rather than hardcoded lists, and a spec that
        -- fails the build when a body's health drifts out of the band it claims
        -- (tests/bestiary_spec.lua).
        tier = def.tier,
        -- The discipline this body IS, for a body built as one (data/disciplines/*.lua). Sparse: most
        -- bodies carry none, and the ones that do are the discipline exemplars plus the Elite-rung
        -- humanoids that read as a deeper cut of their faction. Declared rather than derived from the
        -- kit, so the spec can check the kit against it instead of trusting it -- an Elite that claims
        -- Thief and carries no thief item is the failure this field exists to catch. `class` must be
        -- one of the discipline's parent classes, the same invariant items obey.
        discipline = def.discipline,
        -- A general/boss blueprint sets `boss = true`; carried through so an ability can refuse to work
        -- on one (Coup de Grace won't execute a boss, Charm won't turn it). Nil for an ordinary unit.
        boss = def.boss,
        -- Can this body be brought back once it falls? Default true; a blueprint opts OUT with
        -- `revivable = false` (demons do not come back). A non-revivable unit skips the whole downed
        -- window (models/combat.lua killUnit / reanimate): it dies to a plain corpse with no countdown,
        -- and every revive path refuses it. Baked to a clean boolean here (`~= false`), so absent/true
        -- both read as revivable and only an explicit false opts out.
        revivable = def.revivable ~= false,
        -- Board footprint: how many cells this body covers, as { w, h } anchored at its top-left.
        -- A blueprint's `footprint = { w = 2, h = 2 }` makes a 2×2 ogre; absent (the case for every
        -- ordinary character) normalizes to 1×1, the single tile the whole engine assumed before.
        footprint = Character.normalizeFootprint(def.footprint),
        -- How this body fights when nobody is driving it (models/ai.lua): the posture that decides
        -- whether it engages and how it moves, plus any blueprint-authored rules layered over the
        -- posture's defaults. Both optional -- a character that names neither plays as `aggressive`,
        -- which is what every enemy in the game did before postures existed.
        --
        -- Copied EXPLICITLY, like everything else on this table. Character.instantiate builds the
        -- runtime character field by field rather than cloning the blueprint, so a new field that
        -- isn't named here reads back nil at runtime and fails silently (docs/adding-content.md).
        archetype = def.archetype,
        ai = def.ai,
        -- What this body stands in front of (models/ai.lua's AI.postedUnit): a character id, or
        -- "priority" for "whoever my side cannot afford to lose", ranked off the board each turn.
        -- A `defensive` unit takes a post and holds it; this decides that post instead of letting the
        -- arena's objective decide it, which is how a BODYGUARD differs from a guard -- Rowan defends
        -- the player on every map, including the many that name no objective at all. Nil for everyone
        -- else, which leaves the objective reading untouched.
        guards = def.guards,
        -- The two items that ARE this character, named by the blueprint: its weapon and its signature
        -- verb. General identity ("what is this unit, in two items"), not a mode-specific field --
        -- Draft mode is simply the first consumer, stripping a bought body down to exactly these
        -- (models/draft_chassis.lua). AUTHORED, never derived: no rule over the kit picks them
        -- reliably. The Ninja's priciest discipline item is Scatterlight (480g), but the item its
        -- build is actually about is Vanishing Strike (300g) -- price, position and type all get that
        -- wrong, and only the author knows. Either may be absent (a plain class template owns a weapon
        -- and no signature verb); the strip degrades gracefully when they are.
        signatureWeapon = def.signatureWeapon,
        signatureAbility = def.signatureAbility,
        level = (progress and progress.level) or 1,
        growth = (progress and progress.growth) or {},
        -- The fractional part a blended level-up could not spend in whole points, carried into the next
        -- one (models/growth.lua). Rides beside `growth` because it is the same quantity, unrounded.
        growthCarry = (progress and progress.growthCarry) or {},
        -- THE LEDGER, { [key] = amount } where key is a class id OR a discipline id. Earned per action
        -- and never decremented -- see Character.recordTechnique for what each of the three tables is.
        technique = (progress and progress.technique) or {},
        techniqueSpent = (progress and progress.techniqueSpent) or {},
        techniqueAtLevel = (progress and progress.techniqueAtLevel) or {},
        -- The per-key ledger of levels credited, in shares. Only ever grows, and is what gates the deep
        -- cut of a vendor's shelf (Discipline.level).
        growthBy = (progress and progress.growthBy) or {},
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
