-- Art-debt report: run with
--
--     & "E:\LOVE\lovec.exe" . art-report
--
-- Sweeps every .lua file in the source tree for `assets/...` path literals, checks each against
-- what is actually on disk, and prints the outstanding art debt bucketed by folder. This is the
-- live counterpart to docs/art-assets.md: the doc holds the DECISIONS (sizes, sourcing, style
-- rules, the artist brief), this tool holds the COUNTS, so the numbers can never go stale by
-- being retyped. Re-run it after dropping in new art and paste the summary back into the doc.
--
-- Every path the game can ask for is a reference, whether or not the file exists -- models/sprite.lua
-- resolves missing art to the path string rather than crashing, which is exactly why the debt is
-- invisible without a sweep like this one.
--
-- Read-only: it touches no files. Pass `missing` to also list the outstanding filenames per bucket:
--
--     & "E:\LOVE\lovec.exe" . art-report missing

local M = {}

-- Directories that never contain source references (and would be slow or pointless to walk).
-- `tests` is skipped deliberately: a spec's stand-in sprite path (assets/none.png) exists to prove
-- the tolerant loader handles a missing file, so counting it as art somebody owes would be wrong.
-- `tools` is skipped for the same reason: the icon pipeline builds output paths from an "assets/"
-- prefix, which is plumbing, not a request for art.
local SKIP = {
    assets = true, tests = true, tools = true, vendor = true,
    [".git"] = true, [".claude"] = true, docs = true,
}

-- Bucket display order: the board and character work first, since that is what an incoming artist
-- is actually quoted on. Anything not listed here is appended alphabetically.
--
-- No `hazards` bucket, and there will not be one: zones are drawn procedurally by shaders/field.lua
-- and no blueprint names a sprite, so nothing in the source references assets/hazards/ for this to
-- count. That is the 24 pieces this report used to carry as outstanding forever.
local ORDER = {
    "portraits", "chars", "vendors", "hub",
    "overworld", "traps", "props", "walls",
    "items", "materials", "fonts",
}

-- Recursively collect every .lua file under `dir` ("" is the project root).
local function sourceFiles(dir, out)
    out = out or {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = (dir == "") and name or (dir .. "/" .. name)
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            if not SKIP[name] then sourceFiles(path, out) end
        elseif name:match("%.lua$") then
            out[#out + 1] = path
        end
    end
    return out
end

-- Every distinct "assets/..." literal referenced anywhere in the source, as a sorted list.
local function referencedPaths()
    local seen = {}
    for _, file in ipairs(sourceFiles("")) do
        local text = love.filesystem.read(file) or ""
        -- Quoted literals only, so a path built by concatenation (e.g. "assets/chars/avatar_" .. n)
        -- contributes its prefix and is reported as such rather than being silently missed.
        -- An ellipsis means prose (a comment or a doc example), never a path worth chasing.
        for path in text:gmatch('"(assets/[^"]*)"') do
            if not path:find("%.%.%.") then seen[path] = true end
        end
    end

    local list = {}
    for path in pairs(seen) do list[#list + 1] = path end
    table.sort(list)
    return list
end

-- Group paths into { bucket -> { present = {...}, missing = {...} } } by their second segment.
local function bucketize(paths)
    local buckets = {}
    for _, path in ipairs(paths) do
        -- A prefix from a concatenated path has no filename to check; count it as a bucket note
        -- rather than a missing file, since the real filenames are generated at runtime.
        local isPrefix = not path:match("%.%a+$")
        local name = path:match("^assets/([^/]+)/") or "(root)"
        local b = buckets[name]
        if not b then
            b = { present = {}, missing = {}, prefixes = {} }
            buckets[name] = b
        end

        if isPrefix then
            b.prefixes[#b.prefixes + 1] = path
        elseif love.filesystem.getInfo(path) then
            b.present[#b.present + 1] = path
        else
            b.missing[#b.missing + 1] = path
        end
    end
    return buckets
end

-- Buckets in ORDER first, then any stragglers alphabetically.
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

-- Public: the bucketed scan, so tools/icon_map.lua can ask "what art is still outstanding?"
-- without duplicating the sweep and drifting from what this report prints.
function M.scan()
    return bucketize(referencedPaths())
end

function M.run(args)
    local listMissing = false
    for _, a in ipairs(args or {}) do
        if a == "missing" then listMissing = true end
    end

    local buckets = bucketize(referencedPaths())
    local names = orderedNames(buckets)

    local totalHave, totalNeed = 0, 0
    print("")
    print("Art debt -- referenced by the source vs. present on disk")
    print("")
    print(string.format("  %-12s %8s %8s   %s", "bucket", "have", "needed", "status"))
    print("  " .. string.rep("-", 46))

    for _, name in ipairs(names) do
        local b = buckets[name]
        local have, need = #b.present, #b.present + #b.missing
        totalHave, totalNeed = totalHave + have, totalNeed + need

        -- A bucket holding only folder roots names no files; its prefixes are reported below instead.
        if need > 0 then
            local status = (have == need) and "done" or string.format("%d outstanding", need - have)
            print(string.format("  %-12s %8d %8d   %s", name, have, need, status))
        end
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
                for _, path in ipairs(b.missing) do
                    print("  " .. (path:match("([^/]+)$") or path))
                end
                print("")
            end
        end
    end

    -- Folder roots and concatenated prefixes name no single file, so they can't be existence-checked.
    -- Surface them rather than hiding them: each still stands for art somebody has to draw.
    for _, name in ipairs(names) do
        for _, prefix in ipairs(buckets[name].prefixes) do
            print(string.format("note: %s names no single file -- not counted above", prefix))
        end
    end
end

return M
