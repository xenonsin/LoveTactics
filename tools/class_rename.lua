-- THE RENAME, step 6 of docs/class-fold.md: `& "E:\LOVE\lovec.exe" . class-rename [apply]`
--
-- Pure mechanics and no behaviour: the module that owns the 46 classes stops being called Discipline,
-- and the folder that holds them stops being called disciplines. Deliberately the LAST step of the
-- fold and deliberately separable -- everything before it changed what the game does, and this changes
-- only what the code calls it, so it can be verified by the suite alone.
--
-- WHAT IT DOES NOT TOUCH, and each of these is a decision rather than an oversight:
--
--   member names   `Class.CLASS_LEVEL_CAP` and `Class.classLevel` stutter, and renaming them is a
--                  second pass with its own diff. The stutter is honest; a half-finished member rename
--                  would not be.
--   lowercase ids  `disciplineLocked`, `disciplineId` and friends are locals and parameters. They are
--                  swept here too, because leaving them is exactly the half-renamed state this whole
--                  fold exists to end.
--   doc filenames  docs/disciplines-plan.md keeps its name. It is the plan for the system that BECAME
--                  the class ladder, the wiki publishes it under that title, and every other doc links
--                  to it. Its contents are swept like any other file.
--
-- Files are read and written "rb"/"wb" so a CRLF tree stays a CRLF tree; the two path moves are left to
-- the caller (git mv), so history follows them.

local M = {}

-- Ordered: the longest, most specific patterns first, so a broad one cannot eat a narrow one's text.
-- Lua patterns, with `%f[%w_]` frontiers standing in for a word boundary (Lua has no \b).
--
-- PATHS are rewritten everywhere, including in prose: a doc that points at models/discipline.lua after
-- the move is pointing at nothing, and that is a broken link rather than a style preference.
local PATHS = {
    { '%f[%w_]models%.discipline%f[^%w_]', "models.class" },
    { "models/discipline%.lua", "models/class.lua" },
    { '%f[%w_]data%.disciplines%f[^%w_]', "data.classes" },
    { "data/disciplines", "data/classes" },
    { "tests/discipline_spec%.lua", "tests/class_ladder_spec.lua" },
}

-- IDENTIFIERS are rewritten in CODE ONLY, and that boundary is the whole judgment in this tool.
-- `Discipline` in a .lua file is the module, every time. In a .md file it is a word -- the design
-- concept, often in a sentence about how the system came to be -- and a sweep that rewrote those would
-- turn recorded history into a claim the project never made, in files nobody diffed carefully because
-- "it was just a rename". Doc prose is an editorial pass, not a mechanical one.
local IDENTIFIERS = {
    { "%f[%w_]Discipline%f[^%w_]", "Class" },
    { "%f[%w_]disciplineLocked%f[^%w_]", "classLocked" },
    { "%f[%w_]disciplineId%f[^%w_]", "classId" },
}

local SKIP_DIRS = { [".git"] = true, vendor = true, assets = true, art = true }

local function read(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local function write(path, s)
    local f = io.open(path, "wb"); if not f then return false end
    f:write(s); f:close(); return true
end

local function walk(dir, out)
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local p = (dir == "" and name) or (dir .. "/" .. name)
        local info = love.filesystem.getInfo(p)
        if info and info.type == "directory" then
            if not SKIP_DIRS[name] then walk(p, out) end
        elseif p:match("%.lua$") or p:match("%.md$") then
            out[#out + 1] = p
        end
    end
    return out
end

function M.run(args)
    local apply = false
    for _, a in ipairs(args or {}) do if a == "apply" then apply = true end end

    local files, touched, hits = walk("", {}), 0, 0
    table.sort(files)
    for _, path in ipairs(files) do
        -- The tool skips ITSELF. Its rule table is written in the very strings it rewrites, so a sweep
        -- that included this file would turn `{ "data/disciplines", "data/classes" }` into
        -- `{ "data/classes", "data/classes" }` -- leaving a tool that reads as a no-op and no record of
        -- what the pass actually did.
        local src = path ~= "tools/class_rename.lua" and read(path) or nil
        if src then
            local out, n = src, 0
            for _, rule in ipairs(PATHS) do
                local replaced, count = out:gsub(rule[1], rule[2])
                out, n = replaced, n + count
            end
            if path:match("%.lua$") then
                for _, rule in ipairs(IDENTIFIERS) do
                    local replaced, count = out:gsub(rule[1], rule[2])
                    out, n = replaced, n + count
                end
            end
            if n > 0 then
                touched = touched + 1
                hits = hits + n
                print(string.format("  %-52s %d", path, n))
                if apply then write(path, out) end
            end
        end
    end

    print(string.format("\n%d file(s), %d replacement(s)", touched, hits))
    if not apply then
        print("Report only -- nothing was written. Add `apply` to write.")
    else
        print("\nNow move the files (git mv, so history follows):")
        print("  git mv models/discipline.lua models/class.lua")
        print("  git mv data/disciplines data/classes")
        print("  git mv tests/discipline_spec.lua tests/class_ladder_spec.lua")
    end
end

return M
