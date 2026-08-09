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
local Descent = require("models.descent")
local Growth = require("models.growth")
local Item = require("models.item")
local Material = require("models.material")

local Save = {}

Save.FILE = "save.lua"

-- Bump when the *schema* changes shape (not when game content changes). A save whose
-- version doesn't match is discarded rather than half-read into a broken player.
-- v2: the created avatar -- player.gender + a per-character display name (char.name) override.
-- v3: gender ("F"/"M") became body (1/2), and the name moved to creation, so it is stored on the
--     player too (player.name) rather than only on the avatar instance.
Save.VERSION = 3

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

    -- Player-authored tactics (ui/tactics_editor.lua): the gambit list, the posture backing it, and
    -- whether the unit runs itself. All three are optional and are written ONLY when set, so a
    -- character who never opened the Tactics tab diffs clean -- the same rule defaultActionSlot above
    -- follows, and the reason an empty list is dropped rather than stored as `{}`.
    --
    -- Purely additive, so Save.VERSION deliberately does NOT move: a version bump discards the whole
    -- save, and no existing field changed shape. An older save simply loads with no tactics, which is
    -- exactly what it had.
    -- The player's rule overlay. Its very EXISTENCE is the ownership flag (models/ai.lua): a nil list
    -- means "never edited, still on the blueprint's rules", so an untouched character diffs clean, while
    -- an owned-but-emptied list (the player deleted every rule) must survive as `{}` rather than reading
    -- back as un-owned and resurrecting the blueprint's rules. So: written whenever it is non-nil.
    if char.aiRules then snap.aiRules = char.aiRules end
    -- The archetype is normally the blueprint's, and re-derived by instantiate; only a player
    -- OVERRIDE is worth storing, or every save would carry a copy of content it already has.
    local bpArchetype = bp and bp.archetype
    if char.archetype ~= bpArchetype then snap.archetype = char.archetype or false end
    if char.autoBattle then snap.autoBattle = true end

    -- Progression (models/growth.lua). Level defaults back to 1 on load, so omit it while unleveled to
    -- keep an early-game save diffing clean; the same for an empty tally / no accumulated growth.
    if char.level and char.level > 1 then snap.level = char.level end

    local growth = {}
    for stat, amount in pairs(char.growth or {}) do
        if amount and amount ~= 0 then growth[stat] = amount end
    end
    if next(growth) then snap.growth = growth end

    -- The fraction of a point a blended level-up could not spend, carried into the next one
    -- (Growth.applyLevelBlend). Dropping it would lose up to a point per stat per save/load, which
    -- over a campaign is a character quietly growing worse for having been saved.
    local carry = {}
    for stat, amount in pairs(char.growthCarry or {}) do
        if amount and amount ~= 0 then carry[stat] = amount end
    end
    if next(carry) then snap.growthCarry = carry end

    -- The per-key ledger of levels credited. Fractional now (Growth.resolve books shares), so this is
    -- stored as written rather than rounded -- Discipline.level does the flooring when it gates a shelf.
    local growthBy = {}
    for class, count in pairs(char.growthBy or {}) do
        if count and count > 0 then growthBy[class] = count end
    end
    if next(growthBy) then snap.growthBy = growthBy end

    -- THE LEDGER and its two companions (Character.recordTechnique). Earned is monotonic; spent and the
    -- level checkpoint both only ever rise toward it. Each omitted while empty, like their neighbours
    -- above, so an early save stays small and readable.
    local technique = {}
    for id, amount in pairs(char.technique or {}) do
        if amount and amount > 0 then technique[id] = amount end
    end
    if next(technique) then snap.technique = technique end

    local spent = {}
    for id, amount in pairs(char.techniqueSpent or {}) do
        if amount and amount > 0 then spent[id] = amount end
    end
    if next(spent) then snap.techniqueSpent = spent end

    local atLevel = {}
    for id, amount in pairs(char.techniqueAtLevel or {}) do
        if amount and amount > 0 then atLevel[id] = amount end
    end
    if next(atLevel) then snap.techniqueAtLevel = atLevel end

    return snap
end

-- Fold a PRE-MERGE character snapshot into the one ledger. Before, a character carried `classUse` (one
-- tick per action, the growth vote) and `technique` (two per action, disciplines only, spendable); now
-- it carries earned + spent + a level checkpoint (models/character.lua).
--
-- Done here as a read-time fold rather than by moving Save.VERSION, because a version mismatch
-- DISCARDS THE WHOLE SAVE (Save.load) -- a heavy price for a change that can be read forward exactly.
--
-- Earned is reconstructed at the merged rate: `classUse` counted every action, so it multiplies up to
-- what the same play would bank today. Spent is deliberately reset to nothing rather than derived from
-- the gap between the two old numbers -- that gap also contains the old per-battle cap's clipping, so
-- deriving it would bill the player for forges they never made. Everyone's banks come back full once.
local function migrateLedger(snap)
    if not snap.classUse or snap.techniqueSpent then return end

    local Discipline = require("models.discipline")
    local technique = snap.technique or {}
    for key, count in pairs(snap.classUse) do
        local reconstructed = (count or 0) * Discipline.TECHNIQUE_PER_ACTION
        if reconstructed > (technique[key] or 0) then technique[key] = reconstructed end
    end
    snap.technique = next(technique) and technique or nil

    -- What was already spent toward the CURRENT level is not recoverable either, and starting the
    -- checkpoint at zero would hand every loaded character one free level's worth of reading. Seed it
    -- from the earned figure minus what the old since-level tally says is still outstanding.
    local atLevel = {}
    for key, amount in pairs(snap.technique or {}) do
        local outstanding = ((snap.classUseSinceLevel or {})[key] or 0) * Discipline.TECHNIQUE_PER_ACTION
        local checkpoint = amount - outstanding
        if checkpoint > 0 then atLevel[key] = checkpoint end
    end
    snap.techniqueAtLevel = next(atLevel) and atLevel or nil

    snap.classUse, snap.classUseSinceLevel = nil, nil
end

-- ---------------------------------------------------------------------------
-- Run persistence (the active overworld traversal; see states/game.lua)
-- ---------------------------------------------------------------------------
--
-- So quitting mid-quest and choosing Continue drops the player back onto the map where they left off.
-- Unlike the rest of the save this is a SNAPSHOT, not blueprint ids: an in-progress maze cannot be
-- re-rolled to match (the encounter pool draws in unspecified `pairs` order, so the same seed would
-- reshuffle the stops), so the board is stored whole. It is DELIBERATELY isolated from progression -- if
-- the run is unreadable on load (a removed quest, a malformed board) it is dropped and the player simply
-- resumes at the hub, roster and gold intact. states/game.lua parks the live grid + map widget on
-- `player.activeRun` while a resumable quest is under way; only board quests do (the prologue's scripted
-- legs have no hub to resume into).
--
-- UNLIKE the rest of the save this DOES persist current HP/mana/stamina (see the file header for why the
-- player save doesn't): mid-run attrition is the point, and without it Continue would be a free heal --
-- reload before a hard fight and the party is whole again. The values ride on the RUN, not the character
-- snapshot, so a real return to the hub still restores everyone (Player.restore); only a resume keeps the
-- wounds. Applied back in states/game.lua's resume path, which -- being a resume, not a hub visit -- is the
-- one entry that does not refill them.

-- Live `run` (grid + map widget references on player.activeRun) -> plain data. Nil if there is no run.
-- `player` is passed so the party's current resource pools can be captured alongside the board.
function Save.snapshotRun(run, player)
    if not (run and run.grid and run.map) then return nil end
    local keysHeld = {}
    for keyId in pairs(run.map.keysHeld or {}) do keysHeld[keyId] = true end
    -- The run's own material haul, still unbanked (Quest.complete pays it out at the objective). Without
    -- this a resumed run would walk back over already-picked caches with nothing to show for them.
    local cacheHaul = {}
    for matId, count in pairs(run.map.cacheHaul or {}) do cacheHaul[matId] = count end
    -- Current resource pools per character id (the same key formation uses -- roster ids are unique).
    -- Only pools that exist are stored; a member at full simply reloads to the same value.
    local resources = {}
    for _, char in ipairs(player and player.roster or {}) do
        local pools
        for _, stat in ipairs(Character.RESOURCE_STATS) do
            local res = char.stats and char.stats[stat]
            if type(res) == "table" and res.current then
                pools = pools or {}
                pools[stat] = res.current
            end
        end
        if pools and char.id then resources[char.id] = pools end
    end
    return {
        questId = run.questId,
        prestige = run.prestige,
        -- A DESCENT run: the floor stack and its seed, from which the whole board re-derives. Present
        -- only for a descent; a legacy board quest stores nothing here and restores through questId
        -- exactly as it always did. Plain data by contract -- see models/descent.lua's header on why a
        -- floor descriptor is never allowed onto the run.
        descent = run.descent and Descent.snapshot(run.descent) or nil,
        px = run.map.px,
        py = run.map.py,
        keysHeld = keysHeld,
        cacheHaul = cacheHaul,           -- forging materials picked this run, banked at the objective
        abilityState = run.abilityState, -- companion overworld scratch (banked vigils/steps/...); plain data
        relicState = run.relicState,     -- run relics carried this quest ({ held, scratch }); plain data
        resources = resources,
        -- The company as it walked in: a full Save.snapshot taken once at run start and carried by
        -- reference (never re-taken), so leaving without the objective can put everything back. This is
        -- what makes the run's finds PROVISIONAL -- a chest lands in the stash and equips immediately,
        -- but it is not yours until the objective banks it. See states/game.lua's rollbackRun.
        entry = run.entry,
        grid = run.grid:snapshot(),
    }
end

-- Plain data -> a resume descriptor states/game.lua can enter with, or nil (drop the run, resume at hub).
function Save.restoreRun(snap)
    if type(snap) ~= "table" or not snap.questId or type(snap.grid) ~= "table" then return nil end

    -- A descent floor is not in Quest.defs and never will be -- its descriptor is synthesized. So the
    -- descent branch is taken BEFORE the lookup, or every resumed descent would be discarded here as
    -- "quest content removed since the run was saved". A legacy board quest falls through to the
    -- original path untouched, which is what lets a player mid-quest at upgrade time finish it.
    local descent, quest
    if snap.descent then
        descent = Descent.restore(snap.descent)
        -- The rollback point is stored once, at the run level, and handed back to the descent here --
        -- see Descent.snapshot on why it is not serialized twice. Without this the descent would resume
        -- with no way back and the next floor's game.enter would mint a fresh snapshot, silently banking
        -- everything the run had found so far.
        if descent then descent.entry = snap.entry end
        quest = descent and Descent.floorQuest(descent)
        if not quest then return nil end -- unreadable descent: drop the run, keep the player
    else
        quest = require("models.quest").get(snap.questId)
        if not quest then return nil end -- quest content removed since the run was saved
    end

    local ok, grid = pcall(require("models.overworld").fromSnapshot, snap.grid)
    if not ok or not grid then return nil end
    return {
        questId = snap.questId,
        quest = quest,
        descent = descent,
        prestige = snap.prestige or 1,
        px = snap.px, py = snap.py,
        keysHeld = snap.keysHeld or {},
        cacheHaul = snap.cacheHaul or {},
        abilityState = snap.abilityState or {},
        relicState = snap.relicState or { held = {}, scratch = {} }, -- run relics; see snapshotRun
        resources = snap.resources or {}, -- charId -> { health/mana/stamina = current }; see snapshotRun
        -- The rollback point, carried through a quit-and-Continue. A resumed run WITHOUT one (an older
        -- save, written before the run kept its entry) simply cannot roll back: the rest of the run is
        -- still perfectly playable, so this degrades to the previous behaviour rather than dropping a
        -- board the player is standing on.
        entry = snap.entry,
        grid = grid,
    }
end

function Save.snapshot(player)
    -- The roster IS the company (every owned character marches), so there is one list to store and no
    -- second one whose members have to be re-aliased back onto it at load. An older save still carries
    -- a `party` index list; it is simply ignored on restore.
    local roster = {}
    for i, char in ipairs(player.roster) do
        roster[i] = snapshotCharacter(char)
    end

    local stash = {}
    for i, item in ipairs(player.stash or {}) do stash[i] = snapshotItem(item) end

    local standing = {}
    for vendorId, n in pairs(player.standing or {}) do
        if (tonumber(n) or 0) > 0 then standing[vendorId] = n end
    end
    local wounds = {}
    for charId, n in pairs(player.wounds or {}) do
        if (tonumber(n) or 0) > 0 then wounds[charId] = n end
    end
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

    -- Which vendors have played their first-visit intro (states/hub.lua). A set of ids; only the true
    -- ones are stored. Purely additive, like aiRules -- Save.VERSION does not move, so an older save
    -- loads with none visited (its shops simply greet the player once, which is harmless).
    local visitedVendors = {}
    for vendorId, seen in pairs(player.visitedVendors or {}) do
        if seen then visitedVendors[vendorId] = true end
    end

    local announcedDisciplines = {}
    for disciplineId, seen in pairs(player.announcedDisciplines or {}) do
        if seen then announcedDisciplines[disciplineId] = true end
    end

    -- The red-dot ledgers: item ids that arrived in the stash, and item ids a quest put on a shelf,
    -- neither yet looked at (Player.markNew). Same shape and same additive rule as the flags above --
    -- Save.VERSION does not move, and an older save loads with nothing marked, which reads as a player
    -- who has already seen everything they own. Written only when non-empty so a clean game diffs clean.
    local newItems, newStock
    for itemId, unseen in pairs(player.newItems or {}) do
        if unseen then newItems = newItems or {}; newItems[itemId] = true end
    end
    for itemId, unseen in pairs(player.newStock or {}) do
        if unseen then newStock = newStock or {}; newStock[itemId] = true end
    end

    -- How many times this campaign has been finished and carried forward (Player.newGamePlus). Purely
    -- additive, so Save.VERSION deliberately does NOT move -- same rule aiRules and visitedVendors
    -- follow above: a bump discards the whole save, and no existing field changed shape here. An older
    -- save loads with no count, which reads as a first run, which is what it is.
    -- Omitted while zero so a save that has never finished the game diffs clean.
    local ngPlus = (player.ngPlus or 0) > 0 and player.ngPlus or nil

    -- Who took the field last battle, by charId -- the deployment phase's opening pick, a convenience
    -- and never a rule (models/player.lua's Player.noteDeployed). Placement itself is decided per battle
    -- and is deliberately not saved. Purely additive, so Save.VERSION does not move: an older save loads
    -- with none remembered and its next deployment phase simply opens with nobody pre-selected.
    -- Kept by charId (never by roster index) so it survives a roster reshuffle; omitted while empty.
    local lastDeployed
    for _, id in ipairs(player.lastDeployed or {}) do
        if id then
            lastDeployed = lastDeployed or {}
            lastDeployed[#lastDeployed + 1] = id
        end
    end

    -- The active overworld run, if one is under way (states/game.lua parks it on player.activeRun).
    -- Isolated behind a pcall so a problem reading the live grid can never take the whole save down with
    -- it -- a lost run is recoverable (resume at the hub), lost progression is not.
    local run
    if player.activeRun then
        local ok, r = pcall(Save.snapshotRun, player.activeRun, player)
        run = ok and r or nil
    end

    return {
        version = Save.VERSION,
        gold = player.gold,
        prestige = player.prestige,
        run = run,
        ngPlus = ngPlus,
        body = player.body, -- the created avatar's body (1/2); nil before character creation
        name = player.name, -- the name typed at creation (also on the avatar instance)
        -- Who this player is to other players (Player.authorId). Persisted rather than re-minted,
        -- or every load would look like a new person and a player could be matched against the
        -- build their own previous session published. Nil on a save that never needed one.
        authorId = player.authorId,
        completedQuests = completedQuests,
        -- STANDING WITH EACH HOUSE, as { [vendorId] = circles cleared }, and the deepest floor ever
        -- reached. What the descent banks at extraction (Descent.extract) in place of what a completed
        -- quest used to bank: the shelf reads the first through Quest.sponsorProgress, and the second
        -- is the only thing that levels the company. Both purely additive, so Save.VERSION does not
        -- move -- an older save restores with no standing and a deepest of zero, which reads as a
        -- company that has never gone down, which is exactly what it is.
        standing = standing,
        deepest = player.deepest or 0,
        -- What each body is still carrying from a fight it lost, as { [charId] = count }
        -- (models/wound.lua). Persisted rather than derived because it is the one thing about a run
        -- that outlives the run -- including a wipe, which states/game.lua's rollbackRun holds this
        -- key across on purpose.
        wounds = wounds,
        -- The supper bought at the Cafe and not yet eaten through (models/meal.lua) -- a bare meal id,
        -- nil when nobody has ordered. Purely additive, so Save.VERSION deliberately does NOT move: an
        -- older save loads with no meal held, which reads as a company that has not been to the counter
        -- yet, which is exactly what it is.
        meal = player.meal,
        materials = materials,
        recipes = recipes,
        visitedVendors = visitedVendors,
        announcedDisciplines = announcedDisciplines,
        newItems = newItems,
        newStock = newStock,
        lastDeployed = lastDeployed,
        roster = roster,
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
    -- Fold a pre-merge save's two tallies into the one ledger before anything reads them.
    migrateLedger(snap)

    -- Pass the saved progression through instantiate, which re-bakes the accumulated growth onto the
    -- base stats (max for resource pools) so the character loads at its full leveled power.
    local char = Character.instantiate(snap.id, {
        level = snap.level,
        growth = snap.growth,
        growthCarry = snap.growthCarry,
        growthBy = snap.growthBy,
        technique = snap.technique,
        techniqueSpent = snap.techniqueSpent,
        techniqueAtLevel = snap.techniqueAtLevel,
    })

    -- A save written before per-class level crediting existed carries no `growthBy`, so the ledger
    -- would read as a character that had never levelled at all. Seed it the way that save's stats were
    -- actually earned: under the old rule every level went to the single dominant class, so crediting
    -- the whole climb there reproduces exactly the history those baked stats came from. Guarded on the
    -- field being absent, so a current save is never rewritten.
    if snap.growthBy == nil and (char.level or 1) > 1 then
        char.growthBy = { [Growth.dominantClass(char)] = char.level - 1 }
    end

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

    -- Player-authored tactics. `archetype` is stored as `false` when the player cleared a blueprint's
    -- archetype back to the default, which has to be distinguishable from "not saved" -- so the
    -- absent case leaves whatever instantiate derived, and the explicit false clears it.
    if snap.aiRules then char.aiRules = snap.aiRules end
    if snap.archetype ~= nil then char.archetype = snap.archetype or nil end
    if snap.autoBattle then char.autoBattle = true end
    return char
end

-- Shared with models/build.lua, which freezes a party and its authored tactics for someone else to
-- fight (see that module's header). A build is the same question this file already answers -- what
-- of a character is worth writing down, and how does it come back -- so it reuses these rather than
-- keeping a second opinion about it. Two definitions of "a character on disk" would drift, and the
-- one that drifted would be the one nobody tested.
Save.snapshotCharacter = snapshotCharacter
Save.restoreCharacter = restoreCharacter
Save.encode = encode
Save.decode = decode
Save.known = known

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

    -- `snap.party` (an older save's marching subset) is deliberately not read: the roster is the
    -- company now, so a save made when it was a subset loads with everyone marching -- which is what
    -- the game would have done with them anyway.

    local stash = {}
    for _, itemSnap in ipairs(snap.stash or {}) do
        if known(Item.defs, itemSnap.id) then
            stash[#stash + 1] = Item.instantiate(itemSnap.id, itemSnap.quantity, itemSnap.level)
        end
    end

    local standing = {}
    for vendorId, n in pairs(snap.standing or {}) do
        -- A house that no longer exists in data is dropped rather than restored, the same rule every
        -- other id-keyed table here follows: a stale vendor would otherwise hold standing nothing can
        -- ever spend and no shop can ever show.
        if require("models.vendor").get(vendorId) then standing[vendorId] = tonumber(n) or 0 end
    end
    local wounds = {}
    for charId, n in pairs(snap.wounds or {}) do
        -- A character blueprint that vanished from data drops its wounds with it, the same rule the
        -- standing above follows: nothing should carry an injury that no body can be mended of.
        if require("models.character").defs[charId] then wounds[charId] = tonumber(n) or 0 end
    end
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

    -- Visited-vendor flags (states/hub.lua's first-visit intros). A plain id set; nil on a save from
    -- before this existed, which loads as empty -- its shops greet the player once, no harm done.
    local visitedVendors = {}
    for vendorId, seen in pairs(snap.visitedVendors or {}) do
        if seen then visitedVendors[vendorId] = true end
    end

    -- Discipline-unlocked announcement flags (states/hub.lua). Same shape and same forgiving default:
    -- nil on an older save loads empty, so an already-unlocked discipline simply announces once more.
    local announcedDisciplines = {}
    for disciplineId, seen in pairs(snap.announcedDisciplines or {}) do
        if seen then announcedDisciplines[disciplineId] = true end
    end

    -- The red-dot ledgers (Player.markNew). An id no longer in data/ is dropped like every other, so a
    -- removed item cannot leave a dot on nothing.
    local newItems, newStock = {}, {}
    for itemId, unseen in pairs(snap.newItems or {}) do
        if unseen and known(Item.defs, itemId) then newItems[itemId] = true end
    end
    for itemId, unseen in pairs(snap.newStock or {}) do
        if unseen and known(Item.defs, itemId) then newStock[itemId] = true end
    end

    -- Who was fielded last battle, by charId. An id no longer on the roster is harmless -- the
    -- deployment phase only ever asks about a live company member -- so it is kept as-is rather than
    -- filtered, the same forgiving default the flags above take.
    local lastDeployed = {}
    for _, id in ipairs(snap.lastDeployed or {}) do
        if type(id) == "string" then lastDeployed[#lastDeployed + 1] = id end
    end

    -- The active overworld run, rehydrated into a resume descriptor (or nil when there is none, or it is
    -- unreadable). states/menu.lua's Continue enters states.game with it; anything else drops the player at
    -- the hub. Kept separate from `activeRun` (the LIVE grid+map builder states/game.lua parks while playing)
    -- so the two never collide -- this one is consumed once, on resume.
    local resumeRun = snap.run and Save.restoreRun(snap.run) or nil

    return {
        gold = snap.gold or 0,
        prestige = snap.prestige or 1,
        resumeRun = resumeRun,
        ngPlus = snap.ngPlus or 0, -- absent on a save from before New Game+, and on any first run
        body = snap.body, -- nil for a save made before character creation set it
        name = snap.name,
        authorId = snap.authorId, -- nil on an older save; Player.authorId mints one on demand
        completedQuests = completedQuests,
        standing = standing,          -- absent on a save from before the descent; an empty table reads the same
        deepest = snap.deepest or 0,  -- ...and a company that has never been down has no record to beat
        wounds = wounds,              -- ...nor any bones to set
        -- A meal id that vanished from data/ is dropped rather than crashing the load, exactly like a
        -- removed item or character -- and reads as a company that has not eaten.
        meal = known(require("models.meal").defs, snap.meal) and snap.meal or nil,
        materials = materials,
        recipes = recipes,
        visitedVendors = visitedVendors,
        announcedDisciplines = announcedDisciplines,
        newItems = newItems,
        newStock = newStock,
        lastDeployed = lastDeployed,
        roster = roster,
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
