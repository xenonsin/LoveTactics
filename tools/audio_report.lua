-- Audio-debt report: run with
--
--     & "E:\LOVE\lovec.exe" . audio-report
--     & "E:\LOVE\lovec.exe" . audio-report missing    -- also list the outstanding filenames
--
-- The sibling of tools/art_report.lua, and it exists for the same reason: models/sound.lua resolves a
-- missing sound to silence rather than crashing, which is what lets audio land one file at a time --
-- and is exactly why the debt is invisible without a sweep like this one. A silent game and a
-- fully-scored one are the same number of errors: zero.
--
-- Where the art report has to SCAN the source for `assets/...` literals (because art paths are spread
-- across hundreds of blueprints), this one reads a single table: data/sounds.lua is the whole roster
-- by construction. That makes it exact rather than heuristic -- there are no unresolvable prefixes
-- here, and no "names no single file" footnotes.
--
-- Read-only: it touches no files.

local M = {}

-- Bucket display order. Music first: it is the largest single lift, the most expensive to
-- commission, and the thing whose absence a player notices in the first ten seconds.
local ORDER = { "music", "ui", "battle", "quest" }

-- The bucket a cue belongs to: its id up to the first dot ("battle.hit" -> "battle"). Cue ids are
-- authored `<area>.<thing>` precisely so this needs no second mapping table to maintain.
local function bucketOf(id)
    return (id:match("^([^.]+)")) or "other"
end

-- Scan the cue table against the filesystem. Returns buckets of { present, missing } plus the cue
-- count, shared with M.run so nothing is counted twice by two different rules.
function M.scan()
    local ok, cues = pcall(require, "data.sounds")
    if not ok or type(cues) ~= "table" then return {}, 0 end

    -- Sorted, so a run's output is stable and two runs diff cleanly.
    local ids = {}
    for id in pairs(cues) do ids[#ids + 1] = id end
    table.sort(ids)

    local buckets = {}
    for _, id in ipairs(ids) do
        local def = cues[id]
        local name = bucketOf(id)
        buckets[name] = buckets[name] or { present = {}, missing = {} }

        local file = def and def.file
        local exists = file and love.filesystem.getInfo(file) ~= nil
        local list = exists and buckets[name].present or buckets[name].missing
        list[#list + 1] = file or id
    end
    return buckets, #ids
end

local function orderedNames(buckets)
    local names, seen = {}, {}
    for _, name in ipairs(ORDER) do
        if buckets[name] then names[#names + 1] = name; seen[name] = true end
    end
    local rest = {}
    for name in pairs(buckets) do
        if not seen[name] then rest[#rest + 1] = name end
    end
    table.sort(rest)
    for _, name in ipairs(rest) do names[#names + 1] = name end
    return names
end

function M.run(args)
    local listMissing = false
    for _, a in ipairs(args or {}) do
        if a == "missing" then listMissing = true end
    end

    local buckets = M.scan()
    local names = orderedNames(buckets)

    local totalHave, totalNeed = 0, 0
    print("")
    print("Audio debt -- declared in data/sounds.lua vs. present on disk")
    print("")
    print(string.format("  %-12s %8s %8s   %s", "bucket", "have", "needed", "status"))
    print("  " .. string.rep("-", 46))

    for _, name in ipairs(names) do
        local b = buckets[name]
        local have, need = #b.present, #b.present + #b.missing
        totalHave, totalNeed = totalHave + have, totalNeed + need
        local status = (have == need) and "done" or string.format("%d outstanding", need - have)
        print(string.format("  %-12s %8d %8d   %s", name, have, need, status))
    end

    print("  " .. string.rep("-", 46))
    print(string.format("  %-12s %8d %8d   %d outstanding",
        "TOTAL", totalHave, totalNeed, totalNeed - totalHave))
    print("")

    if listMissing then
        for _, name in ipairs(names) do
            local b = buckets[name]
            if #b.missing > 0 then
                print(string.format("%s (%d):", name, #b.missing))
                for _, path in ipairs(b.missing) do print("  " .. path) end
                print("")
            end
        end
    end

    if totalHave == 0 and totalNeed > 0 then
        print("note: the game currently ships no audio at all. Every cue above is wired and silent --")
        print("      dropping a file at any path listed makes that one cue start playing, with no")
        print("      code change. See docs/roadmap.md, Phase 2.")
        print("")
    end
end

return M
