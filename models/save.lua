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
    -- The seal, and the ONE field identification adds to this schema (models/identify.lua). It carries
    -- the floor the piece was found on rather than a boolean, so the fee, the sell price and the
    -- reveal's ceiling all read one number -- and the LEVEL beside it is already the rolled answer,
    -- sitting in the field it will still be sitting in after somebody pays to look at it. A husk
    -- therefore needs no second hiding place: the save stores the truth and the game withholds it.
    if item.unidentified and item.unidentified > 0 then snap.unidentified = item.unidentified end
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

    -- Experience toward the next level (models/experience.lua). Written for EVERY character, not only a
    -- descent's, because combat banks it in every mode and a snapshot that dropped it would quietly
    -- reset a resumed descent's progress to the last whole level. Omitted at zero for the same reason
    -- `level` is: an unfought body should not put a field in the file. Purely additive, so an older save
    -- restores at zero, which is what a body that has never swung reads as anyway.
    if char.xp and char.xp > 0 then snap.xp = char.xp end

    local growth = {}
    for stat, amount in pairs(char.growth or {}) do
        if amount and amount ~= 0 then growth[stat] = amount end
    end
    if next(growth) then snap.growth = growth end

    -- How many bonds' worth of growth the table above already contains (models/voucher.lua's
    -- Summon.applyGrowth). Persisted BECAUSE the growth is: the packet is folded into `growth` and
    -- re-baked on load like every other point, so without this mark the next Summon.applyBond would
    -- fold it in a second time and a bonded body would grow a little every time the game was loaded.
    if (char.bonded or 0) > 0 then snap.bonded = char.bonded end

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
    -- THE DAY'S WORK, so a resume comes back with the same boxes ticked. The ids are stored rather than
    -- re-derived from the board on load: clearing a piece of work takes it OFF the board, so asking the
    -- board again mid-expedition would hand back a shorter list than the player is standing on
    -- (models/quest.lua's Quest.tripFromIds).
    local trip, tripDone
    if run.trip then
        trip = { groundId = run.trip.groundId, questIds = {} }
        for _, id in ipairs(run.trip.questIds or {}) do
            trip.questIds[#trip.questIds + 1] = id
        end
        tripDone = {}
        for id, done in pairs(run.tripDone or {}) do
            if done then tripDone[id] = true end
        end
    end

    return {
        questId = run.questId,
        day = run.day,
        trip = trip,
        tripDone = tripDone,
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
    if snap.trip and snap.trip.groundId then
        -- A GROUND the company was walking, rather than a single piece of work. Rebuilt from the ids
        -- the run carried, exactly like the descent branch below rebuilds a floor: the synthesized id
        -- (`trip:tundra`) is not in Quest.defs and never will be, so the lookup further down would
        -- discard a perfectly good expedition as "content removed since the run was saved".
        quest = require("models.quest").tripFromIds(snap.trip.groundId, snap.trip.questIds)
        if not quest then return nil end -- every quest on it is gone: nothing left to resume onto
    elseif snap.descent then
        descent = Descent.restore(snap.descent)
        -- The rollback point is stored once, at the run level, and handed back to the descent here --
        -- see Descent.snapshot on why it is not serialized twice. Without this the descent would resume
        -- with no way back and the next floor's game.enter would mint a fresh snapshot, silently banking
        -- everything the run had found so far.
        if descent then descent.entry = snap.entry end
        -- NO PLAYER TO HAND IT, and the floor descriptor that comes back is thinner for it: a floor's
        -- ends are read off the player (which errands are open, which houses are still shut), so this
        -- one carries the stair alone. This runs inside Save.load, which is building the table a player
        -- is made FROM -- there is nothing here to pass. It is enough to answer the only question asked
        -- here, which is whether the run can be resumed at all; states/game.lua's enter re-synthesizes
        -- the descriptor against the live player before the board is read against it. See the comment
        -- there for what a stair-only objectives list did to an errand seated on the floor.
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
        -- The day the run was ENTERED on, carried with it rather than re-read from the clock on
        -- resume. A resumed expedition is the same expedition: it already spent its day, and a board
        -- that re-read the calendar would scale to a different depth halfway through itself.
        day = snap.day or 1,
        -- The ground and which of its work is already taken, so the checklist comes back ticked.
        trip = snap.trip,
        tripDone = snap.tripDone or {},
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

    -- WHAT THE TOUCHSTONE IS HOLDING (models/identify.lua). Unnamed pieces the player sold, kept for
    -- buying back, and they have to persist for the same reason the stash does: a buy-back the player
    -- can only reach before the next save is not an offer, it is a trap. Snapshotted through the same
    -- helper, so a shelved husk comes back sealed exactly as a stashed one does.
    local touchstoneShelf = {}
    for i, item in ipairs(player.touchstoneShelf or {}) do touchstoneShelf[i] = snapshotItem(item) end

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

    -- WHICH CITY DOORS HAVE BEEN SHOWN (models/building.lua's seenDoors block). A door the city grows is
    -- coached once -- a bubble on its card, every other card refused -- and this is what keeps it to
    -- once across a save. Same additive rule as the two above: Save.VERSION does NOT move.
    --
    -- NIL AND EMPTY ARE DIFFERENT HERE, which is why this is not written unconditionally. Nil means the
    -- ledger has never been seeded, and an older save has exactly that -- so it loads with nil, the hub
    -- seeds it off whatever that company has already earned, and a player who has been using the Forge
    -- for hours is not marched back through an announcement for it. A seeded ledger is never empty (the
    -- plaza always has three open cards), so nothing legitimate is lost by dropping an empty one.
    local seenDoors
    for id, seen in pairs(player.seenDoors or {}) do
        if seen then seenDoors = seenDoors or {}; seenDoors[id] = true end
    end

    -- Story flags (models/story_effect.lua's `effect = { flag = ... }`, read back by a scene's
    -- `when = { flag = ... }`). Same shape and same additive rule as the two above: Save.VERSION does
    -- NOT move, and an older save loads with nothing flagged -- which reads as a player who has not
    -- answered any of it yet. Written only when non-empty so a clean game diffs clean.
    local flags
    for flagId, set in pairs(player.flags or {}) do
        if set then flags = flags or {}; flags[flagId] = true end
    end

    -- The temptation ledger, { [vendorId] = { taken = n, pressed = n } } (models/temptation.lua).
    -- Stored as counts rather than as the outcome they resolve to, because the outcome is only decided
    -- at a line's slot 10 and the counts have to survive the nine quests before it. A zero pair is
    -- dropped: a line nobody has been offered anything in has nothing to say.
    local temptation
    for vendorId, ledger in pairs(player.temptation or {}) do
        local taken, pressed = tonumber(ledger and ledger.taken) or 0, tonumber(ledger and ledger.pressed) or 0
        if taken > 0 or pressed > 0 then
            temptation = temptation or {}
            temptation[vendorId] = { taken = taken, pressed = pressed }
        end
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

    -- How many times the campaign has been FINISHED, which is a different question from how many times
    -- it has been carried forward -- see Player.finishCampaign. This is what the post-game is gated on,
    -- so it has to be persisted separately from ngPlus rather than inferred from it. Same additive
    -- rule: no VERSION bump, and an older save loads as never-finished, which is what it is.
    local campaignsFinished = (player.campaignsFinished or 0) > 0 and player.campaignsFinished or nil

    -- WHICH DAY THE COMPANY IS STANDING ON (models/calendar.lua). The campaign's clock, and the thing
    -- the whole difficulty curve now reads -- so unlike most of the additive fields here it is not
    -- optional in spirit, only in encoding: omitted while it is 1 so a fresh save diffs clean, and any
    -- save without it loads on the first morning, which is what a save written before the calendar
    -- existed effectively was.
    local day = (player.day or 1) > 1 and player.day or nil

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

    -- WHAT THIS PLAYTHROUGH IS MADE OF (models/seed.lua). Written unconditionally, unlike almost every
    -- other additive field here: a seed is never zero and never uninteresting, and a save that diffs
    -- clean by hiding the one number that describes it would be hiding the wrong thing. A save from
    -- before seeds existed has none and mints one on first use (Seed.base), so no VERSION bump.
    --
    -- The LAP's seed is deliberately not written beside it: it is derived from this number and `ngPlus`
    -- (Seed.lap), and a second stored copy of a derived value is a copy that can disagree.
    local seed = player.seed
    local runsStarted = (player.runsStarted or 0) > 0 and player.runsStarted or nil

    return {
        version = Save.VERSION,
        gold = player.gold,
        prestige = player.prestige,
        run = run,
        seed = seed,
        runsStarted = runsStarted,
        ngPlus = ngPlus,
        campaignsFinished = campaignsFinished,
        day = day,
        body = player.body, -- the created avatar's body (1/2); nil before character creation
        name = player.name, -- the name typed at creation (also on the avatar instance)
        -- Who this player is to other players (Player.authorId). Persisted rather than re-minted,
        -- or every load would look like a new person and a player could be matched against the
        -- build their own previous session published. Nil on a save that never needed one.
        authorId = player.authorId,
        completedQuests = completedQuests,
        -- ERRANDS TAKEN ON AND NOT YET FINISHED, as { questId = floor } (models/errand.lua). A house
        -- asks for a small piece of work before it opens the next rung of its shelf, and the floor is
        -- stored beside the id because the shop has to be able to say WHERE to go -- an errand whose
        -- location the player has to remember is a chore rather than a piece of work.
        --
        -- Purely additive, so Save.VERSION does not move: an older save restores having taken none on.
        errands = player.errands,
        -- THE HIRING PURSE (models/voucher.lua). Four fields, and all four are on the PROFILE rather than
        -- on a run for the same reason: a run ends, the town does not, and a voucher earned on floor six
        -- is the reward for having gone to floor six.
        --
        --   vouchers    HOW MANY tokens are held, as a plain count. It was a list of `{ floor = n }`
        --               while tokens carried a grade; they do not (models/voucher.lua), so there is
        --               nothing to tell one from another and nothing to keep a list of.
        --   bonds       { [charId] = duplicates taken }, which is the level that body's bound relic
        --               stands at (Summon.relicLevel). Keyed by ID rather than by roster instance, the
        --               same call `wounds` makes and for the same reason: the id survives the roster
        --               being rebuilt out of this file.
        --   pulls       how many vouchers have been spent, ever. Half of the pull seed -- see
        --               Voucher.peek for why a pull is seeded differently to everything else in the game.
        --   pullSalt    the other half, minted once per profile so two playthroughs do not deal the
        --               same sequence.
        --
        -- `pity` rides beside them (Summon.PITY) and `staked` survives as a BOOLEAN -- it used to be the
        -- list of bodies the sponsor had put in the hall, and it is now just "has her voucher been
        -- planted". `riggedPull` is the name that voucher calls, and it is spent by the pull that reads
        -- it.
        --
        -- Purely additive, so Save.VERSION does not move: an older save restores with an empty purse and
        -- no bonds, which is a company that has never pulled -- and its retired `declined` list is
        -- simply not read, which drops it on the next write.
        vouchers = player.vouchers,
        bonds = player.bonds,
        pulls = player.pulls,
        pullSalt = player.pullSalt,
        pity = player.pity,
        staked = player.staked == true or nil,
        riggedPull = player.riggedPull,
        -- STANDING WITH EACH HOUSE, as { [vendorId] = circles cleared }, and the deepest floor ever
        -- reached. What the descent USED to bank in place of what a completed quest banks: the shelf
        -- reads the first through Quest.sponsorProgress, and the second levelled the company. Both are
        -- inert now -- a descent is a separate mode and banks nothing (models/descent.lua's
        -- Descent.account) -- and both are still written because a save carries the whole shape and an
        -- older one still holds real numbers here. Purely additive, so Save.VERSION does not
        -- move -- an older save restores with no standing and a deepest of zero, which reads as a
        -- company that has never gone down, which is exactly what it is.
        standing = standing,
        deepest = player.deepest or 0,
        -- What each body is still carrying from a fight it lost, as { [charId] = count }
        -- (models/wound.lua). Persisted rather than derived because it is the one thing about a run
        -- that outlives the run -- including a wipe, which states/game.lua's rollbackRun holds this
        -- key across on purpose.
        wounds = wounds,
        -- ...and whether anybody ever has been (models/wound.lua's Wound.everWounded), which the ledger
        -- above stops being able to answer the moment the surgeon is paid. The Inn is the door it opens.
        -- Purely additive, so Save.VERSION does not move: an older save restores unmarked, and the first
        -- wound taken after loading writes it.
        wounded = player.wounded or nil,
        -- ...and whether this company has ever come back up the stair early. The same shape and the
        -- same reason as `wounded` above: a one-way mark rather than a ledger reading, because
        -- Iselle's tally falls back to nought the moment they descend again and the readout it gates
        -- must not come off the plaza the morning after it was earned (models/descent.lua).
        climbedOut = player.climbedOut or nil,
        tallyTaught = player.tallyTaught or nil, -- ...and whether she has explained it. See Descent.tallyTaught.
        -- The supper bought at the Cafe and not yet eaten through (models/meal.lua) -- a bare meal id,
        -- nil when nobody has ordered. Purely additive, so Save.VERSION deliberately does NOT move: an
        -- older save loads with no meal held, which reads as a company that has not been to the counter
        -- yet, which is exactly what it is.
        meal = player.meal,
        materials = materials,
        recipes = recipes,
        visitedVendors = visitedVendors,
        announcedDisciplines = announcedDisciplines,
        seenDoors = seenDoors,
        flags = flags,
        temptation = temptation,
        newItems = newItems,
        newStock = newStock,
        lastDeployed = lastDeployed,
        roster = roster,
        stash = stash,
        touchstoneShelf = touchstoneShelf,
        -- THE DESCENT THIS COMPANY IS IN THE MIDDLE OF (models/descent.lua). The floor stack, the
        -- shuffled circles, every board it has mapped and whatever it dropped down there. Nil until the
        -- sponsor sends them down, and written through Descent.snapshot rather than raw because a run
        -- holds live grids that Save.encode would refuse.
        --
        -- Purely additive, so Save.VERSION does not move: an older save restores having never gone down,
        -- which is what it is.
        descentRun = player.descentRun
            and require("models.descent").snapshot(player.descentRun) or nil,
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

-- One item snapshot -> one live instance. Every restore path goes through here so that a SEALED piece
-- cannot come back read: rehydrating a husk through Item.instantiate would hand the player the true
-- name, the true stats and the " +n" for free, which is the whole feature undone by a load.
--
-- `models.identify` is required lazily rather than at the top of the file, and that is a cycle rather
-- than a style choice: identify -> player -> save. Same reason models/building.lua reaches for Errand
-- and Wound inside its own functions.
--
-- A blueprint that stopped being sealable since the save was written (its type changed, it became bound,
-- its price was removed) restores READ rather than vanishing. Identify.sealed answers nil there, and
-- losing the piece would be worse than revealing it -- the player still owns a thing they went and found.
local function restoreItem(itemSnap)
    if (itemSnap.unidentified or 0) > 0 then
        local Identify = require("models.identify")
        local husk = Identify.sealed(itemSnap.id, itemSnap.unidentified, itemSnap.level)
        if husk then return husk end
    end
    return Item.instantiate(itemSnap.id, itemSnap.quantity, itemSnap.level)
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

    -- Experience toward the next level, restored onto the body rather than passed through instantiate:
    -- it is a plain counter that nothing about building a character depends on (models/experience.lua
    -- derives the level from it, and the level is already snapshotted), so there is no reason to widen
    -- Character.instantiate's contract for it.
    if snap.xp and snap.xp > 0 then char.xp = snap.xp end

    -- The bond mark, restored beside the growth it accounts for. Absent on a save from before the hall
    -- dealt this way, which reads as a body carrying no bond growth -- exactly right for one that has
    -- never been pulled twice.
    if snap.bonded and snap.bonded > 0 then char.bonded = snap.bonded end

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
            char.inventory[tonumber(cell)] = restoreItem(itemSnap)
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
-- ...and the same for a single ITEM. What a company that wiped leaves behind is everything it was
-- carrying, dropped on the tile it fell on (models/descent.lua's `drops`), and a cell cannot hold live
-- instances -- Save.encode raises on the userdata an instance can carry. Rehydrated through
-- Item.instantiate, which re-bakes the forge level from the blueprint like every other restore.
Save.snapshotItem = snapshotItem
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
            stash[#stash + 1] = restoreItem(itemSnap)
        end
    end

    -- The Touchstone's shelf: pieces sold unnamed and still buyable back (models/identify.lua). Same
    -- restore path as the stash, so a shelved husk comes back sealed rather than in the clear, and the
    -- same id guard, so a piece whose blueprint left the game drops instead of crashing the load.
    local touchstoneShelf = {}
    for _, itemSnap in ipairs(snap.touchstoneShelf or {}) do
        if known(Item.defs, itemSnap.id) then
            touchstoneShelf[#touchstoneShelf + 1] = restoreItem(itemSnap)
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
    -- The hiring purse (models/voucher.lua). Vouchers carry one number and are rebuilt rather than
    -- copied through, so a hand-edited save cannot put a table in the list; bonds are filtered against
    -- the blueprints exactly as wounds are one block up.
    -- THE PURSE IS A COUNT, and a save written while it was a LIST of graded tokens folds into one:
    -- however many tickets it was holding is however many it still holds. Reading the old shape here
    -- rather than bumping Save.VERSION keeps every other field on that save loadable, which is the same
    -- call the `staked` list-to-boolean fold below makes.
    local vouchers = 0
    if type(snap.vouchers) == "table" then
        for _ in ipairs(snap.vouchers) do vouchers = vouchers + 1 end
    else
        vouchers = math.max(0, math.floor(tonumber(snap.vouchers) or 0))
    end
    local bonds = {}
    for charId, n in pairs(snap.bonds or {}) do
        if require("models.character").defs[charId] and (tonumber(n) or 0) > 0 then
            bonds[charId] = math.floor(tonumber(n))
        end
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

    -- Shown-door flags (models/building.lua's seenDoors block). NOT forgiving in the same way as the two
    -- above, and it is the one set here where nil must stay nil: an empty ledger and an unseeded one are
    -- different states, and rebuilding this as `{}` would tell the hub the player has looked at a city
    -- and seen no doors in it -- which would announce every card they already own. Left absent, the hub
    -- seeds it off what that company has already earned. Filtered against the registry like every other
    -- id set: a building deleted from data/ is dropped rather than sat in the ledger forever.
    local seenDoors
    for id, seen in pairs(snap.seenDoors or {}) do
        if seen and known(require("models.building").defs, id) then
            seenDoors = seenDoors or {}
            seenDoors[id] = true
        end
    end

    -- Story flags. Deliberately NOT filtered against any registry, unlike the id sets around it: a flag
    -- is a record that something was answered, not a pointer at a blueprint, and there is nothing to
    -- check it against. An orphaned flag whose scene was deleted is inert -- no `when` asks for it.
    local flags = {}
    for flagId, set in pairs(snap.flags or {}) do
        if set and type(flagId) == "string" then flags[flagId] = true end
    end

    -- The temptation ledger. A vendor that vanished from data/ drops its counts with it, the same rule
    -- standing and wounds follow above -- a line that no longer exists cannot be resolved.
    local temptation = {}
    for vendorId, ledger in pairs(snap.temptation or {}) do
        if known(require("models.vendor").defs, vendorId) and type(ledger) == "table" then
            temptation[vendorId] = {
                taken = tonumber(ledger.taken) or 0,
                pressed = tonumber(ledger.pressed) or 0,
            }
        end
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
        -- THE SEED (models/seed.lua). Nil on a save written before seeds existed, which is the one case
        -- that matters here: Seed.base mints one the first time anything asks, so an old save joins the
        -- scheme instead of being told it has no world. Kept as a number rather than defaulted to zero,
        -- because zero is a seed and "no seed yet" is not.
        seed = tonumber(snap.seed),
        runsStarted = tonumber(snap.runsStarted) or 0, -- descents begun this lap; absent means none yet
        ngPlus = snap.ngPlus or 0, -- absent on a save from before New Game+, and on any first run
        campaignsFinished = snap.campaignsFinished or 0, -- absent until the campaign has been beaten once
        day = snap.day or 1, -- the calendar; absent on a fresh save and on any save older than it
        body = snap.body, -- nil for a save made before character creation set it
        name = snap.name,
        authorId = snap.authorId, -- nil on an older save; Player.authorId mints one on demand
        errands = snap.errands or {},
        -- THE HIRING PURSE. Absent on a save from before the hall dealt this way, and an empty purse
        -- reads as a company that has never pulled -- which is what it is.
        --
        -- `bonds` is filtered against the blueprints the same way `wounds` is, one block up: a character
        -- that vanished from data drops its bonds with it rather than leaving a ledger naming somebody
        -- the game can no longer build.
        --
        -- `staked` was a LIST on an older save (the bodies the sponsor had put in the hall) and is a
        -- boolean now. A truthy table restores as true, which is the honest reading of it: that save's
        -- sponsor had already made good on her clause, so hers is not owed again.
        vouchers = vouchers,
        bonds = bonds,
        pulls = tonumber(snap.pulls) or 0,
        pullSalt = tonumber(snap.pullSalt),
        pity = tonumber(snap.pity) or 0,
        staked = snap.staked ~= nil and snap.staked ~= false,
        riggedPull = known(require("models.character").defs, snap.riggedPull) and snap.riggedPull or nil,
        completedQuests = completedQuests,
        standing = standing,          -- absent on a save from before the descent; an empty table reads the same
        deepest = snap.deepest or 0,  -- ...and a company that has never been down has no record to beat
        wounds = wounds,              -- ...nor any bones to set
        wounded = snap.wounded == true, -- ...and no history of any, which is what an older save reads as
        climbedOut = snap.climbedOut == true, -- ...and has never turned back, which is what one reads as too
        tallyTaught = snap.tallyTaught == true, -- ...so nobody has had to explain the tally to them yet
        -- A meal id that vanished from data/ is dropped rather than crashing the load, exactly like a
        -- removed item or character -- and reads as a company that has not eaten.
        meal = known(require("models.meal").defs, snap.meal) and snap.meal or nil,
        materials = materials,
        recipes = recipes,
        visitedVendors = visitedVendors,
        announcedDisciplines = announcedDisciplines,
        seenDoors = seenDoors,     -- nil on an older save, which is what the hub seeds off (see above)
        flags = flags,             -- absent on a save from before this existed; empty reads as unanswered
        temptation = temptation,   -- ...and an empty ledger resolves every line as `held`, which is right
        newItems = newItems,
        newStock = newStock,
        lastDeployed = lastDeployed,
        roster = roster,
        stash = stash,
        touchstoneShelf = touchstoneShelf,
        -- The descent in progress, rebuilt from plain data (see the note in Save.snapshot). Nil for a
        -- company that has never gone down, and for every save written before there was a stair.
        descentRun = snap.descentRun and require("models.descent").restore(snap.descentRun) or nil,
    }
end

-- ---------------------------------------------------------------------------
-- Disk
-- ---------------------------------------------------------------------------

-- EVERY DISK CALL TAKES AN OPTIONAL FILE, defaulting to the campaign's own. There is a second player-
-- shaped thing in the game now -- a descent's throwaway company, drafted at the mouth of a run and
-- deleted when the run ends (models/descent.lua) -- and it is the same shape all the way down, so it
-- wants this serializer rather than a parallel one. What it must never do is land in `save.lua`.
--
-- Passing the path rather than swapping a module-level "current slot" is deliberate: a slot would be
-- global mutable state that a crash mid-descent could leave pointing at the wrong file, and the failure
-- mode of that is a descent overwriting a campaign. An argument cannot be left set.
local function fileOf(file) return file or Save.FILE end

function Save.exists(file)
    return love.filesystem.getInfo(fileOf(file)) ~= nil
end

-- Returns true on success, or false plus a message.
function Save.write(player, file)
    local source = "-- LoveTactics save. Generated file; edit at your own risk.\nreturn "
        .. encode(Save.snapshot(player), 0) .. "\n"
    return love.filesystem.write(fileOf(file), source)
end

-- The raw decoded snapshot, WITHOUT restoring it into a player. For the handful of questions a caller
-- wants answered about a save it is not about to load -- the main menu asking whether the campaign has
-- ever been finished, so it knows whether to draw the post-game door. Save.read would answer the same
-- question by instantiating the whole roster from blueprints, which is a lot of work to read one
-- integer, and it would do it every time the menu is rebuilt.
--
-- Returns plain saved data, so a caller must treat every field as optional: an older save simply has
-- not got the newer ones. nil if there is no save or it will not decode.
function Save.peek(file)
    if not Save.exists(file) then return nil end
    local source = love.filesystem.read(fileOf(file))
    if not source then return nil end
    return decode(source)
end

-- The restored player, or nil if there is no save (or it is unreadable).
function Save.read(file)
    if not Save.exists(file) then return nil end
    local source = love.filesystem.read(fileOf(file))
    if not source then return nil end
    local snap = decode(source)
    if not snap then return nil end
    return Save.restore(snap)
end

function Save.clear(file)
    if Save.exists(file) then love.filesystem.remove(fileOf(file)) end
end

return Save
