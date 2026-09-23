-- Character (party member) logic. Blueprints live in data/characters/<id>.lua
-- with flat base stats; `Character.instantiate` builds a mutable runtime copy
-- where resource stats are split into { max, current }.

local Registry = require("models.registry")
local Item = require("models.item")
local Sprite = require("models.sprite")
-- WHAT A BODY IS, one axis above what it does (models/race.lua). Required at file scope rather than
-- lazily: every instantiate reads it, and Race is plain data over a registry with no cycle back here.
local Race = require("models.race")

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

-- THE TWO ACCURACY STATS, and why they are a fallback rather than a formula.
--
-- `skill` is how well a body swings: it raises Hit and, halved, Crit. `luck` is how well the world
-- treats it: it raises Avoid, and subtracts from an attacker's crit chance outright, so a lucky body
-- is not harder to hit so much as harder to hit BADLY. See docs/accuracy.md for the arithmetic.
--
-- Both are authored per blueprint, on a 0-10 band chosen to sit beside `defense` (3-6) and `speed`
-- (0-9) rather than tower over them -- Fire Emblem's own stats run 0-20, against a Speed that also
-- runs 0-20, and importing the numbers without the scale would have made these the only stats in the
-- game with a different order of magnitude than the ones they are subtracted from.
--
-- The values below are NOT the design. They exist so that a blueprint which forgets the fields loads
-- and fights instead of erroring in the middle of a battle, and so that a new character file is never
-- blocked on an accuracy decision. What makes the authoring real is that tests/data_spec.lua fails the
-- build over any combatant blueprint still sitting on them: a default nobody is allowed to keep is a
-- safety net rather than a shortcut. (A non-combatant -- a prop, an escortee, a Pig -- is exempt, and
-- keeps them.)
Character.DEFAULT_SKILL = 4
Character.DEFAULT_LUCK = 4

-- Stats that get the fallback above when a blueprint declares none.
Character.ACCURACY_STATS = { skill = Character.DEFAULT_SKILL, luck = Character.DEFAULT_LUCK }

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

-- KIND ROLLS UP FROM RACE, stamped onto the blueprint once at load.
--
-- `kind` is no longer authored anywhere: 167 blueprints used to declare it, and before that a tool
-- GUESSED it from words in the id. Both are gone. What every reader in the tree still wants is the
-- coarse answer -- is this a bodied thing that shops, or a creature that does not -- and there are
-- twenty-odd of them across models, tools and specs. Rather than teach each one to ask a race, the
-- answer is derived here, at the one place a blueprint becomes visible to any of them.
--
-- THIS IS NOT A SECOND LEDGER. It is computed from `race` and is never written by a file; the race is
-- the only thing an author can set, and tests/race_spec.lua reads the blueprint SOURCES to assert that
-- nobody has quietly added a `kind` line back. Deriving it from the field it must agree with is the
-- only arrangement where the two cannot come apart -- which is the whole reason this pass happened.
--
-- A body whose race is missing or misspelled gets nil, loudly, at the same spec.
for _, def in pairs(Character.defs) do
    def.kind = Race.kindOf(def.race)
end

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

-- THE BODY AS IT IS DRAWN, which is not always the body the blueprint named.
--
-- An item in the grid may declare `wearerSkin` -- a word, not a path -- and the bearer is then drawn
-- from a VARIANT of its own token, `<its sprite>_<skin>.png`. Marrowlight declares `bone`, so a knight
-- carrying it draws from `assets/chars/knight_bone.png` and a mage from `mage_bone.png`: their own
-- silhouette, in bone (tools/char_compose.lua composes the variant beside every token it writes).
--
-- A WORD AND NOT A PATH, and that is the whole reason this is a resolver rather than a field copy. The
-- aspect has to be "a skeleton version of THEMSELVES" on every body in the game, and an item naming one
-- file could only ever be one skeleton -- the same anonymous token over a knight, a mage and a wolf,
-- which is the thing this was asked not to be. The item names the TREATMENT; the body supplies the
-- picture; the composer has already written the crossing of the two.
--
-- DERIVED FROM `spritePath` rather than from the character id, so it keeps working for a body whose art
-- stops being composed: a painted knight.png gets a painted knight_bone.png beside it and nothing here
-- changes. It also means a blueprint with no art at all resolves to nothing and falls through, rather
-- than inventing a path.
--
-- FALLS BACK RATHER THAN FAILING. Sprite.load is tolerant -- a missing file comes back as the path
-- string -- and a string handed to a drawer that wanted an image lands on that surface's no-art
-- placeholder, which on the board is the bare letter disc. So the variant is asked for by EXISTENCE
-- (Sprite.exists) and the body keeps its own sprite when there is no variant on disk. An un-built
-- assets/ therefore costs the skeleton its bone token and nothing else.
--
-- READ AT DRAW TIME, never cached on the character, for the reason Item.rulesFor gives about rules: the
-- grid changes at a camp, at a counter and on the loadout screen, and a skin baked in at the mouth of
-- the stair would outlive the charm that granted it. The walk is nine cells and Sprite.load is memoized,
-- so the cost is a table lookup.
function Character.spriteOf(char)
    if not char then return nil end
    local base = char.spritePath
    if type(base) == "string" then
        for _, item in ipairs(Character.eachItem(char)) do
            local skin = item.wearerSkin
            if type(skin) == "string" and skin ~= "" then
                local variant = base:gsub("%.png$", "_" .. skin .. ".png")
                if variant ~= base and Sprite.exists(variant) then return Sprite.load(variant) end
            end
        end
    end
    return char.sprite
end

-- Which field on an ITEM carries a bonus to `key`: `maxBonus` for a resource pool, `bonus` for a flat
-- stat. THE one answer to that question, because getting it wrong is silent -- an item raising
-- `bonus.health` raises no ceiling anywhere in Combat, and a reader that checked `bonus` for HP would
-- report nothing where a Toughness charm plainly does something. Combat keeps the two apart deliberately
-- (applyUnitPassives folds `bonus` into unit.bonus for Combat.flatStat and `maxBonus` into char.maxBonus
-- for Combat.unreservedMax); this is that same split, exposed so the readouts cannot each guess.
function Character.bonusField(key)
    return isResourceStat(key) and "maxBonus" or "bonus"
end

-- Everything feeding one stat on this member: { { label, value }, ... }, base first and then one row per
-- piece of gear that moves it.
--
-- "Base" is the body itself -- the blueprint value with its banked level-ups already in it. They are one
-- row because they are one fact from the player's side: this is what the character is worth naked. The
-- split between them is a bookkeeping detail of how Growth.resolve stores things, and a tooltip about
-- gear is not the place to explain it.
--
-- TWO DIFFERENT FIELDS, and reading the wrong one is silent. A flat stat is raised by `item.bonus`,
-- which Combat folds into unit.bonus for Combat.flatStat. A resource CEILING is raised by
-- `item.maxBonus` instead (Toughness, Endurance, Attunement), which lands in char.maxBonus for
-- Combat.unreservedMax. They are deliberately separate over there, so a reader that checked only
-- `bonus` would report nothing at all on exactly the three rows -- HP, MP, SP -- whose ceilings a player
-- most wants accounted for.
--
-- Statuses are absent on purpose rather than forgotten -- Status.statBonus is a battle-time reading of a
-- live unit, and nothing here is in a battle.
--
-- This lives on the model rather than on the sheet that prints it because it has a second reader now:
-- models/muster.lua rates a body by exactly these numbers, and a model may not require a panel. The
-- Loadout sheet keeps its Party.statSources/statTotal names as delegates. Pure and static (no panel, no
-- love.graphics, no Combat), so it is unit-testable -- see tests/party_spec.lua.
function Character.statSources(char, key)
    if not (char and key) then return {} end
    local live = char.stats and char.stats[key]
    local resource = type(live) == "table"
    local base = resource and (live.max or 0) or live
    if type(base) ~= "number" then return {} end

    local parts = { { label = "Base", value = base } }
    local field = Character.bonusField(key)
    for _, item in ipairs(Character.eachItem(char)) do
        local v = item[field] and item[field][key]
        if v and v ~= 0 then
            parts[#parts + 1] = { label = item.name or "Equipment", value = v }
        end
    end
    return parts
end

-- The figure the sheet PRINTS for `key`: every source above, summed -- so the number on the row and the
-- rows in its tooltip cannot disagree, because they are the same list added up two ways.
--
-- This is the effective stat, gear included. It did not use to be: the sheet printed char.stats alone,
-- and equipped gear reached the number only once Combat.applyUnitPassives ran at the start of a battle.
-- A member reading "Attack 17" with a +6 spear in the grid actually swung for 22, and no surface said
-- so -- the sheet quietly described a body with its kit taken off. For a resource this is the CEILING;
-- `current` is left alone, so a wounded member still reads as wounded against the raised max, exactly as
-- it already did against the unraised one.
function Character.statTotal(char, key)
    local total = 0
    for _, part in ipairs(Character.statSources(char, key)) do total = total + part.value end
    return total
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
-- discipline id, whichever the item votes for (Class.growthClasses).
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
--   `techniqueSpent`    what the Forge has billed (Class.spendTechnique). Available to spend is
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
-- Class.level existed to prevent. The bill spends from whichever body holds the most
-- (Class.techniqueHolder), so gear stays free to circulate while the pressure stays on the body.
--
-- No `Class` require here: this module stays dependency-light, and only the caller
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

    -- Fill in skill/luck for a blueprint that declares neither (see Character.ACCURACY_STATS). Done
    -- HERE rather than at the point of use so that every reader -- the combat formulas, the character
    -- sheet, muster's rating of a body, the debug editor writing a blueprint back out -- sees one
    -- number, and none of them has to know the default exists.
    for key, fallback in pairs(Character.ACCURACY_STATS) do
        if stats[key] == nil then stats[key] = fallback end
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
        -- WHAT A BODY IS (data/races/*.lua): "human" | "naga" | "demon" | "beast" | "undead" |
        -- "construct" | "elemental" | "object". One axis above `class` below -- a naga knight and a
        -- naga mage are both nagas, and neither fact tells you the other. A race carries RULES and a
        -- FIXED stat line and may never carry a growth table; see models/race.lua for the whole of
        -- that discipline.
        race = def.race,
        -- ...and what KIND of body that makes it: "humanoid" | "beast" | "demon" | "undead" |
        -- "construct" | "elemental" | "object". DERIVED FROM THE RACE and no longer authored anywhere.
        --
        -- It was authored on 167 blueprints, and it was a GUESS before that -- tools/char_compose
        -- inferred it from words in the id and defaulted to "most portraitless enemies are people",
        -- which read every wolf and boar in the folder as a humanoid because nothing in
        -- "character_boar" says otherwise. Two authored ledgers of one fact drift; this one is derived,
        -- so a race is the only place the answer lives.
        --
        -- It still means exactly what it always meant, and every rule downstream is untouched: it is
        -- the line the bestiary's outfitting rule is drawn along (docs/bestiary.md). A HUMANOID carries
        -- priced, lootable, shareable gear off a shelf and names the class that shelf belongs to; every
        -- other kind carries natural weapons only -- unpriced, `noSteal`, never a discipline item. A
        -- wolf is not a Beastmaster; a wolf is what a Beastmaster has.
        --
        -- Nil for a blueprint whose `race` is missing or misspelled, which is what makes that a loud
        -- failure at tests/race_spec.lua rather than a quiet one at a shelf.
        kind = Race.kindOf(def.race),
        -- Which RUNG of the ladder this body sits on (docs/bestiary.md): 1 chaff · 2 line · 3 elite ·
        -- 4 boss, or 0 for a body that is not on the ladder at all -- a prop, an escortee, or a shape
        -- worn by Wild Shape. A DECLARED LABEL, never a multiplier: nothing derives a stat from it.
        -- What it buys is encounters composed as budgets rather than hardcoded lists, and a spec that
        -- fails the build when a body's health drifts out of the band it claims
        -- (tests/bestiary_spec.lua).
        tier = def.tier,
        -- The discipline this body IS, for a body built as one (data/classes/*.lua). Sparse: most
        -- bodies carry none, and the ones that do are the discipline exemplars plus the Elite-rung
        -- humanoids that read as a deeper cut of their faction. Declared rather than derived from the
        -- kit, so the spec can check the kit against it instead of trusting it -- an Elite that claims
        -- Thief and carries no thief item is the failure this field exists to catch. `class` must be
        -- one of the discipline's parent classes, the same invariant items obey.
        discipline = def.discipline,
        -- A general/boss blueprint sets `boss = true`; carried through so an ability can refuse to work
        -- on one (Coup de Grace won't execute a boss, Charm won't turn it). Nil for an ordinary unit.
        boss = def.boss,
        -- A PLANT body -- a sapling, a heartwood tree, a mandrake -- is one the Dryad line's grain runs
        -- through (models/grove.lua): a Nymph steps out beside it, the Hamadryad moves foes between them.
        -- Nil for everything else.
        plant = def.plant,
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
        -- INNATE MITIGATION: { tag -> flat damage reduction }, the body's own hide, scale, husk or
        -- grave-cold, in exactly the unit an armour's `resist` table is written in and summed into the
        -- same total (Combat.applyUnitPassives).
        --
        -- It exists because the mitigation formula is subtractive and half the bestiary has nothing to
        -- subtract WITH. A humanoid layers a coat over its `defense` stat and so carries two numbers
        -- into a blow: the stat, and a per-tag line that says which weapon the coat is actually for.
        -- A beast, a demon, an elemental and a construct wear nothing, so every one of the 71 creature
        -- bodies went into a fight with an empty resist table -- and the measurement said so twice
        -- over. They subtracted about 30% less than an armoured humanoid of the same rung, and, worse,
        -- their slash, pierce and impact mitigation were the SAME NUMBER, every body, every rung.
        -- docs/balance.md measures four probes because "a body that walls slash and folds to impact is
        -- not unbalanced, it is a puzzle"; there was no puzzle here to measure. A fire elemental had
        -- magicDefense 10 and no `fire` line, so a Fireball and a Frostbolt landed on it identically.
        --
        -- NEGATIVE IS A WEAKNESS, the same sign convention a status's `vulnerable` uses
        -- (docs/vulnerability.md) and the one data/items/utility/utility_demonic_essence.lua already
        -- ships as `resist = { holy = -8 }`. That matters more than the positive half: this pass is a
        -- REDISTRIBUTION, not a buff. Creatures already sat near the top of their time-to-kill bands,
        -- so a body that turns a blade aside pays for it by opening somewhere else, and the best melee
        -- probe's TTK stays inside Balance.TTK. What changes is which weapon gets there.
        --
        -- Copied field-by-field like everything else on this table, and SHALLOW-COPIED rather than
        -- referenced: a blueprint is immutable and shared by every body minted from it, so handing the
        -- runtime character the def's own table would let one unit's future edit reach every wolf.
        -- THE RACE'S LINE IS THE FLOOR AND THE BLUEPRINT'S LAYERS OVER IT. A naga's scale is a fact
        -- about every naga (data/races/naga.lua) and is stated once; a particular body that is tougher
        -- than its kin says so here and wins the tag. Same order, and the same argument, as the item
        -- fold one layer further out in Combat.applyUnitPassives: flesh first, then what was put on
        -- top of it.
        resist = (function()
            local out, any = {}, false
            for tag, amount in pairs(Race.get(def.race) and Race.get(def.race).resist or {}) do
                out[tag] = amount; any = true
            end
            for tag, amount in pairs(def.resist or {}) do out[tag] = amount; any = true end
            return any and out or nil
        end)(),
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
        -- THE DECLARED CLASS: the one thing that decides how this body grows on a level-up
        -- (Growth.classOf). Nil until the player picks one, and the blueprint's innate `class` is the
        -- fallback until they do -- so a fresh recruit grows as what it was minted as rather than
        -- standing still waiting to be told.
        --
        -- A SEPARATE FIELD FROM `class`, which is the blueprint's own and never moves. The player may
        -- stand a body anywhere on the ladder it has opened; what it was minted as is still what it
        -- falls back to, so the two cannot be one field.
        --
        -- This replaced `growthBy`, a per-key ledger of levels credited in shares, back when growth was
        -- apportioned across everything a body had swung. The class level that ledger fed is read off
        -- cumulative technique now (Class.classLevel), so the two questions -- how does this body
        -- grow, what has it got good at -- are answered by two fields that cannot drift apart.
        declaredClass = (progress and progress.declaredClass) or nil,
        inventory = {},
        -- Hidden fallback weapon (never in inventory, never shown in the item grid). Sourced
        -- from the blueprint's `unarmed` id or the generic default; explicitly `false` for a body
        -- with no natural weapon at all (see Character.DEFAULT_UNARMED), which leaves this nil.
        unarmed = def.unarmed ~= false and Item.instantiate(def.unarmed or Character.DEFAULT_UNARMED) or nil,
    }

    -- THE RACIAL STAT LINE, folded into the BASE stats rather than banked as a bonus.
    --
    -- Combat's flatStat reads `char.stats[name]` as the base and adds the grid, the statuses, the
    -- traits and the ground on top; a race belongs underneath all four, because it is not something the
    -- body is carrying or standing on -- it is the body. Folding it here also makes it FIXED by
    -- construction: it lands once, at instantiate, and no level-up can ever touch it. That is the
    -- border between a race and a class stated in code rather than in a comment.
    --
    -- Resource stats have already been split into { max, current } by this point, so a line naming one
    -- moves the ceiling and tops the pool up to it -- a race that granted health would grant it whole
    -- rather than leaving a body spawning wounded. Nothing ships one; the path exists so the first race
    -- that does is not a special case somebody has to notice.
    for stat, amount in pairs(Race.statBonus(def.race)) do
        local cur = char.stats[stat]
        if type(cur) == "table" then
            cur.max = (cur.max or 0) + amount
            cur.current = cur.max
        elseif type(cur) == "number" then
            char.stats[stat] = cur + amount
        end
    end

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

    -- WHAT THE RACE PUTS IN THE GRID (data/races/*.lua's `grants`): a naga's own coils, and in time a
    -- demon's crown. Bound, unstealable, and seeded AFTER the authored layout so a designer's own cell
    -- assignments are never displaced -- the grant takes the first free cell and nothing else moves.
    --
    -- This is what makes the race do real work rather than being a label. Combat.isAquatic scans the
    -- grid for the `swim` tag and needs no second place to look; four naga blueprints do not each have
    -- to remember to carry their own legs; and the fifth naga somebody writes cannot forget. The cost
    -- is a grid cell, which is the price the demons have always paid for their own.
    --
    -- A body with a full grid simply does not get it. That is a loud enough failure to be worth leaving
    -- unguarded -- it means a nine-item blueprint of a race that grants something, which is an
    -- authoring mistake the race spec catches by counting cells rather than a runtime case to handle.
    for _, itemId in ipairs(Race.grantsOf(def.race)) do
        for cell = 1, Character.MAX_INVENTORY do
            if not char.inventory[cell] then
                char.inventory[cell] = Item.instantiate(itemId)
                break
            end
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
