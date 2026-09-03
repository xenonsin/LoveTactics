-- What the shipped game actually REACHES -- the instrument for deciding what content can go.
--
--     & "E:\LOVE\lovec.exe" . content-report          # the summary, by reason
--     & "E:\LOVE\lovec.exe" . content-report full     # ... and every scene, grouped
--
-- WHY THIS EXISTS. On 2026-08-24 I deleted 49 conversation files after checking one play site and
-- concluding the quest lines were unreachable. They were not: the campaign's completion path
-- (states/game.lua's `doneQuest.outro`) has had no caller since the Quest Board was retired -- the
-- comment there says so -- but the DESCENT has its own, and it plays a finished errand's outro
-- (states/game.lua, inside the Errand.complete branch). Two paths, one dead and one live, forty lines
-- apart in the same file. Reasoning about reachability by reading is how that happens.
--
-- So this asks the model layer instead, through the same functions the runtime calls:
--
--   * Errand.forVendor / Errand.opener -- which house quests the descent can actually post. NOT the
--     whole line: the pool is every `_slot_01` plus every quest that gates a discipline, so a house's
--     other slots are authored content the descent never surfaces.
--   * Errand.postingScene -- the per-house errand scene, else the generic one.
--   * VendorVisit -- the greeting and the discipline announcement, per vendor.
--   * The encounter blueprints' own `conversation` field.
--
-- The other half is the DEAD-BY-ROUTE set, and it is deliberately reported separately from orphans: a
-- quest `intro`/`epilogue`/`followUp` is wired correctly and would play tomorrow if the Quest Board came
-- back (models/building.lua's RETIRED is one line). That is parked, not garbage, and a report that
-- called it garbage would be arguing for deleting the campaign rather than measuring it.

local Registry = require("models.registry")
local Conversation = require("models.conversation")
local Errand = require("models.errand")
local Quest = require("models.quest")
local Vendor = require("models.vendor")

local M = {}

-- TWO SWEEPS, AND NEITHER ENUMERATES A FIELD NAME. The first version of this file listed the fields it
-- expected a scene to hang off (`intro`, `outro`, `opening`, `objective.conversation`) and missed two
-- routes immediately: models/descent.lua names each sin's confrontation on a `scene` field in a table of
-- its own, and a quest's confrontation sits on `opening` NESTED inside an objective rather than at the
-- top level. Both showed up as orphans -- the seven generals and the Hollow Crown among them, which is
-- the most-played content in the game.
--
-- So: walk every value at every depth and take any string that names a scene. A field this file has
-- never heard of cannot hide a route from it.
local function walkIds(value, seen, out)
    seen = seen or {}
    out = out or {}
    if type(value) == "string" then
        if Conversation.defs[value] then out[value] = true end
        return out
    end
    if type(value) ~= "table" or seen[value] then return out end
    seen[value] = true
    for k, v in pairs(value) do
        walkIds(k, seen, out)
        walkIds(v, seen, out)
    end
    return out
end

-- The code sweep. Any `conversation_*` literal in a model or state is a scene something reaches for by
-- name -- states/hub.lua's prologue pair, states/gate.lua's tally, models/descent.lua's sin table.
--
-- This WILL also catch ids that only appear in comments, and that is the correct direction for a tool
-- whose output is a delete list: over-reporting a scene as reachable costs nothing, and under-reporting
-- one deletes live content. Erring the other way is exactly the mistake this file exists because of.
local CODE_DIRS = { "models", "states", "ui" }
local function namedInCode()
    local found = {}
    for _, dir in ipairs(CODE_DIRS) do
        for _, name in ipairs(love.filesystem.getDirectoryItems(dir) or {}) do
            local path = dir .. "/" .. name
            local info = love.filesystem.getInfo(path)
            if info and info.type == "file" and name:match("%.lua$") then
                local src = love.filesystem.read(path) or ""
                for id in src:gmatch("conversation_[%w_]+") do
                    if Conversation.defs[id] then found[id] = path end
                end
            end
        end
    end
    return found
end

local function lineCountOf(id)
    local def = Conversation.defs[id]
    if not def then return 0 end
    local n = 0
    local function walk(entries)
        for _, e in ipairs(entries or {}) do
            if type(e) == "table" then
                if e[2] then n = n + 1 end
                walk(e.script or e.block or e.then_ or nil)
            end
        end
    end
    walk(def.script)
    return n
end

-- Everything the live routes can reach, as a set of conversation ids mapped to WHY.
local function reachable()
    local live = {}
    local function mark(id, why)
        if type(id) == "string" and Conversation.defs[id] and not live[id] then live[id] = why end
    end

    for id, path in pairs(namedInCode()) do mark(id, "named in code (" .. path .. ")") end

    -- Per vendor: the greeting, the discipline announcement, and the errand scenes.
    for vendorId in pairs(Vendor.defs) do
        mark("conversation_" .. vendorId .. "_vendor_intro", "vendor first visit")
        mark("conversation_" .. vendorId .. "_discipline_unlocked", "discipline announcement")
        -- Both meetings, per companion. There is no generic pair behind these any more
        -- (Errand.postingScene returns nil rather than falling back), so a house that authored neither
        -- reports as a companion nobody can be asked by -- which is the report doing its job.
        for _, kind in ipairs({ "asked", "found" }) do
            mark("conversation_" .. vendorId .. "_errand_" .. kind, "companion posting (" .. kind .. ")")
        end

        -- THE LIVE POSTING. Each class posts exactly one piece of work now -- the ask its companion
        -- makes when you meet them on a floor (models/errand.lua) -- and finishing it plays that
        -- quest's outro and hands the companion over. This is the seam the 2026-08-24 deletion
        -- missed, and it read `Errand.forVendor` until the ladder that function walked was cut.
        for _, questId in ipairs({ Errand.opener(vendorId) }) do
            for id in pairs(walkIds(Quest.defs[questId])) do
                mark(id, "errand pool (" .. questId .. ")")
            end
        end
    end

    -- Every OTHER blueprint folder that can name a scene, walked at any depth.
    --
    -- `data/tutorials` is here because leaving it out cost real content: the tutorial def names its
    -- script on `lines` and its opening scene on `opening`, so `conversation_prologue_village` and
    -- `conversation_tutorial_village` read as orphans and one of them was deleted. The suite caught it
    -- (tests/conversation_spec.lua: "every scene something opens with is a scene that exists"), which is
    -- the second time a guard has caught what this report missed. A folder that can hold a scene id and
    -- is not in this list is a hole of exactly that shape -- add new content folders here.
    for _, spec in ipairs({
        { "data/encounters", "data.encounters" },
        { "data/arenas", "data.arenas" },
        { "data/tutorials", "data.tutorials" },
        { "data/draft", "data.draft" },
        { "data/biomes", "data.biomes" },
    }) do
        local defs = Registry.load(spec[1], spec[2])
        for id, def in pairs(defs) do
            for cid in pairs(walkIds(def)) do mark(cid, spec[1]:match("[^/]+$") .. " " .. id) end
        end
    end

    return live
end

-- Named by a quest the descent cannot post. Correctly wired and would play tomorrow if the Quest Board
-- came back -- parked, not orphaned, and reported apart from the orphans for exactly that reason.
local function campaignOnly(live)
    local out = {}
    for questId, def in pairs(Quest.defs) do
        for id in pairs(walkIds(def)) do
            if not live[id] and not out[id] then out[id] = "named by " .. questId end
        end
    end
    return out
end

-- Every house quest, split by whether the descent can post it. `Errand.forVendor` is the authority --
-- the pool is each house's `_slot_01` plus every quest that gates a discipline -- so this is asked of the
-- model rather than pattern-matched off filenames.
function M.questPool()
    local pool, all = {}, {}
    for vendorId in pairs(Vendor.defs) do
        local ask = Errand.opener(vendorId)
        if ask then pool[ask] = vendorId end
    end
    for id, def in pairs(Quest.defs) do
        if def.sponsor then all[id] = def.sponsor end
    end
    return pool, all
end

-- WHAT DELETING THE UNPOSTABLE QUESTS WOULD COST THE SHELVES, which is the one question standing
-- between "these 49 are unreachable" and actually removing them.
--
-- TWO WAYS AN ITEM DEPENDS ON A QUEST, and they are not the same shape:
--
--   * HANDED OVER. `rewardItems` on the quest. A quest that is deleted takes its grants with it, and
--     an item granted nowhere else and sold nowhere else has no way into the game at all.
--   * GATED BEHIND STANDING. `unlockQuests` on the ITEM is a COUNT -- how many of that house's quests
--     must be finished before the shelf will sell it -- and a house's standing can never exceed the
--     number of its quests that can actually be posted. So deleting quests lowers a ceiling, and every
--     row gated above the new ceiling goes quietly unbuyable. This is the one that does not announce
--     itself: nothing errors, the row simply never appears, and the shelf looks complete.
--
-- The second is why this is a report rather than a grep. `unlockQuests` names no quest, so no search
-- over the doomed files can find what they were holding up.
-- EVERY WAY AN UNPRICED ITEM CAN STILL REACH A PLAYER once its quest is gone. An unpriced item cannot
-- come off a cache, a corpse or a merchant: models/spoils.lua draws its pool from PRICED items inside a
-- price band, and says so. So the sources are finite and worth naming, because the first draft of this
-- report knew about none of them and reported all seven general relics as orphaned when every one of
-- them is paid off the body standing on its circle's stair.
local function otherSources()
    local Descent = require("models.descent")
    local Character = require("models.character")
    local out = {}

    -- What a circle's guardian and its lieutenant hand over. This IS the re-home the retired board's
    -- slot-10 quests used to do, already built (Descent.DROPS).
    for _, drop in pairs(Descent.DROPS or {}) do
        for _, list in pairs({ drop.general or {}, drop.minor or {} }) do
            for _, itemId in ipairs(list) do out[itemId] = "a general or lieutenant drops it" end
        end
    end

    -- What a companion walks in wearing. A house's companion arrives carrying her bound piece, so an
    -- item sitting in one of those blueprints' grids has a source whatever happens to the quests.
    --
    -- WALKED OFF THE VENDORS, which is where the pairing lives: each house names its `companion`
    -- (data/vendors/*.lua) and models/vendor_visit.lua joins them at that counter. It used to walk
    -- models/descent_recruit.lua's roster, which was the same seven bodies read through the floor slate
    -- that dealt them -- and that slate is deleted, since a companion is met at a posting now rather
    -- than offered on a stop.
    local Vendor = require("models.vendor")
    for _, sin in ipairs(Descent.SINS or {}) do
        local vdef = sin.vendor and Vendor.get(sin.vendor)
        local def = vdef and vdef.companion and Character.defs[vdef.companion]
        -- `startingItems` is a GRID, so it carries `false` for an empty cell -- ipairs would stop at the
        -- first hole and silently miss everything after it, which on Rowan is the back half of her kit.
        for _, itemId in pairs((def and def.startingItems) or {}) do
            if type(itemId) == "string" then
                out[itemId] = out[itemId] or "a recruitable body carries it"
            end
        end
    end

    return out
end

local function shelfCost()
    local Item = require("models.item")
    local pool = M.questPool()
    local elsewhere = otherSources()

    local postable, doomed = {}, {}      -- vendorId -> count
    local granted = {}                   -- itemId -> { live = n, doomed = n }
    for id, def in pairs(Quest.defs) do
        local v = def.sponsor
        if v then
            local livePost = pool[id] and true or false
            if livePost then postable[v] = (postable[v] or 0) + 1
            else doomed[v] = (doomed[v] or 0) + 1 end
            for _, itemId in ipairs(def.rewardItems or {}) do
                granted[itemId] = granted[itemId] or { live = 0, doomed = 0 }
                local k = livePost and "live" or "doomed"
                granted[itemId][k] = granted[itemId][k] + 1
            end
        end
    end

    local rows = {}                      -- vendorId -> { ceiling, stranded = {}, orphaned = {} }
    for vendorId in pairs(Vendor.defs) do
        rows[vendorId] = { ceiling = postable[vendorId] or 0, doomed = doomed[vendorId] or 0,
                           stranded = {}, orphaned = {} }
    end

    for itemId, def in pairs(Item.defs) do
        local vendorId = def.class and Vendor.forClass(def.class)
        local row = vendorId and rows[vendorId]
        if row then
            -- Gated above what the house could still reach. `price` is the test for "the shelf sells
            -- it at all": a relic carries no price and no class gate, and is never stranded by standing.
            local gate = tonumber(def.unlockQuests) or 0
            if def.price and gate > row.ceiling then
                row.stranded[#row.stranded + 1] = string.format("%s (needs %d, ceiling %d)", itemId, gate, row.ceiling)
            end
        end
        local g = granted[itemId]
        if g and g.doomed > 0 and g.live == 0 and not def.price and not elsewhere[itemId] then
            -- Handed over ONLY by a doomed quest, and on no shelf to buy instead.
            local vid = (def.class and Vendor.forClass(def.class)) or "(no house)"
            rows[vid] = rows[vid] or { ceiling = 0, doomed = 0, stranded = {}, orphaned = {} }
            rows[vid].orphaned[#rows[vid].orphaned + 1] = itemId
        end
    end
    return rows
end

function M.run(args)
    local full, mode = false, nil
    for _, a in ipairs(args or {}) do
        if a == "full" then full = true end
        if a == "quests" then mode = "quests" end
        if a == "items" then mode = "items" end
    end

    if mode == "items" then
        local rows = shelfCost()
        local names = {}
        for v in pairs(rows) do names[#names + 1] = v end
        table.sort(names)

        local totalStranded, totalOrphaned = 0, 0
        print("")
        print("What deleting the unpostable house quests would cost the shelves")
        print("")
        print("  house            postable  deleted   ceiling   stranded   orphaned")
        print("  ---------------------------------------------------------------------")
        for _, v in ipairs(names) do
            local r = rows[v]
            if r.doomed > 0 or #r.stranded > 0 or #r.orphaned > 0 then
                print(string.format("  %-16s %8d %8d %9d %10d %10d",
                    v, r.ceiling, r.doomed, r.ceiling, #r.stranded, #r.orphaned))
            end
            totalStranded = totalStranded + #r.stranded
            totalOrphaned = totalOrphaned + #r.orphaned
        end
        print("  ---------------------------------------------------------------------")
        print(string.format("  %-16s %8s %8s %9s %10d %10d", "TOTAL", "", "", "", totalStranded, totalOrphaned))
        print("")
        print("  stranded = on a shelf, gated behind more of that house's quests than would still exist.")
        print("             Nothing errors; the row just never appears. Re-gate or the item is gone.")
        print("  orphaned = handed over ONLY by a quest being deleted, and on no shelf to buy instead.")
        print("             Needs a new source (floor loot, a surviving quest's rewardItems) first.")

        if full then
            for _, v in ipairs(names) do
                local r = rows[v]
                if #r.stranded > 0 or #r.orphaned > 0 then
                    print("")
                    print(string.format("== %s ==", v))
                    table.sort(r.stranded); table.sort(r.orphaned)
                    for _, s in ipairs(r.stranded) do print("  stranded  " .. s) end
                    for _, o in ipairs(r.orphaned) do print("  orphaned  " .. o) end
                end
            end
        else
            print("")
            print("  (`. content-report items full` names every one)")
        end
        return
    end

    if mode == "quests" then
        local pool, all = M.questPool()
        local live, dead = {}, {}
        for id, sponsor in pairs(all) do
            local row = id .. "\t" .. sponsor
            if pool[id] then live[#live + 1] = row else dead[#dead + 1] = row end
        end
        table.sort(live); table.sort(dead)
        print("")
        print(string.format("House quests: %d sponsored, %d postable by the descent, %d not",
            #live + #dead, #live, #dead))
        print("")
        print("== POSTABLE (the errand pool -- opener + discipline gates) ==")
        for _, r in ipairs(live) do print("  " .. r) end
        print("")
        print("== NOT POSTABLE (reachable only through the retired Quest Board) ==")
        for _, r in ipairs(dead) do print("  " .. r) end
        return
    end

    local live = reachable()
    local parked = campaignOnly(live)

    local rows = { live = {}, parked = {}, orphan = {} }
    local lines = { live = 0, parked = 0, orphan = 0 }
    local ids = {}
    for id in pairs(Conversation.defs) do ids[#ids + 1] = id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local bucket = live[id] and "live" or (parked[id] and "parked" or "orphan")
        local n = lineCountOf(id)
        lines[bucket] = lines[bucket] + n
        rows[bucket][#rows[bucket] + 1] = { id = id, why = live[id] or parked[id] or "nothing names it", n = n }
    end

    print("")
    print("Conversation reachability -- what the SHIPPED routes can actually play")
    print("")
    print("  bucket    scenes   spoken lines   meaning")
    print("  ------------------------------------------------------------------")
    print(string.format("  live      %6d   %12d   a live route plays it", #rows.live, lines.live))
    print(string.format("  parked    %6d   %12d   wired to the retired Quest Board", #rows.parked, lines.parked))
    print(string.format("  orphan    %6d   %12d   NOTHING names it", #rows.orphan, lines.orphan))
    print("  ------------------------------------------------------------------")
    print(string.format("  total     %6d   %12d", #ids, lines.live + lines.parked + lines.orphan))
    print("")
    print("  parked is PARKED, not dead: models/building.lua's RETIRED is one line, and the campaign")
    print("  plays every one of these the day it comes back. Orphans are the only safe delete.")

    if full then
        for _, bucket in ipairs({ "orphan", "parked", "live" }) do
            print("")
            print(string.format("== %s (%d) ==", bucket:upper(), #rows[bucket]))
            for _, r in ipairs(rows[bucket]) do
                print(string.format("  %-52s %4d  %s", r.id, r.n, r.why))
            end
        end
    else
        print("")
        print("  (`. content-report full` lists every scene and the route that reaches it)")
    end
end

M.reachable = reachable

return M
