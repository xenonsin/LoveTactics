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
        for _, kind in pairs(Errand.SCENES or {}) do mark(kind, "errand posting (generic)") end
        for _, kind in ipairs({ "asked", "found" }) do
            mark("conversation_" .. vendorId .. "_errand_" .. kind, "errand posting (house)")
        end

        -- THE LIVE HOUSE QUESTS. Errand.forVendor is the descent's own pool, and a finished errand
        -- plays its quest's `outro`. This is the seam the 2026-08-24 deletion missed.
        -- THE LIVE HOUSE QUESTS. Errand.forVendor is the descent's own pool -- every `_slot_01` plus
        -- every quest that gates a discipline, NOT the whole line -- and a finished errand plays its
        -- quest's outro. This is the seam the 2026-08-24 deletion missed.
        for _, questId in ipairs(Errand.forVendor(vendorId) or {}) do
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
        for _, questId in ipairs(Errand.forVendor(vendorId) or {}) do pool[questId] = vendorId end
    end
    for id, def in pairs(Quest.defs) do
        if def.sponsor then all[id] = def.sponsor end
    end
    return pool, all
end

function M.run(args)
    local full, mode = false, nil
    for _, a in ipairs(args or {}) do
        if a == "full" then full = true end
        if a == "quests" then mode = "quests" end
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
