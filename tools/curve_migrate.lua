-- Curve migration: rewrites hand-typed per-level rows in data/items/**.lua as models/curve.lua
-- generator calls.
--
--   & "E:\LOVE\lovec.exe" . curve-migrate                 dry run -- every row, its verdict, a summary
--   & "E:\LOVE\lovec.exe" . curve-migrate apply           rewrite the blueprints in place
--   & "E:\LOVE\lovec.exe" . curve-migrate snapshot PATH   dump every resolved magnitude, for diffing
--
-- The safety property is the split between the two halves:
--
--   * rows are ENUMERATED through the loaded model (Item.defs), not by scraping text, so a row nested
--     inside a one-line bonus/resist table is found exactly like one on its own line;
--   * a row is REWRITTEN only when a generator reproduces all eleven of its entries EXACTLY. A row
--     that neither style matches keeps its literal list, which Item.resolveLevel has always accepted.
--     So does a row whose literal the rewriter cannot locate in source -- an unmigrated row is
--     indistinguishable from a deliberately hand-shaped one, and neither breaks anything.
--
-- Which means the migration is not supposed to change any number in the game. `snapshot` is how that
-- is proved rather than asserted: dump before, dump after, diff, expect nothing.
--
-- Writes into the PROJECT source tree (not the LOVE save dir), so it uses io.open with absolute
-- paths, exactly as tools/extract_strings does.

local Item = require("models.item")
local Curve = require("models.curve")

local M = {}

-- The blueprint fields that can hold a tuned magnitude. Mirrors the containers models/item.lua's
-- eachMagnitude walks; the recursion below reaches the nested ones (activeAbility.aoe, aura.status)
-- without naming them, so a new nested magnitude is picked up without editing this list.
local CONTAINERS = { "activeAbility", "bonus", "resist", "maxBonus", "unarmedBonus", "waitBehavior",
                     "incense", "aura" }

-- ---------------------------------------------------------------------------
-- Walking a def / an instance
-- ---------------------------------------------------------------------------

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do if type(k) == "string" then keys[#keys + 1] = k end end
    table.sort(keys)
    return keys
end

-- Is this a per-level row -- a list of exactly LEVELS numbers? Length alone is a strong filter: a
-- magnitude is the only thing in a blueprint authored as an eleven-long run of bare numbers.
local function isCurveRow(v)
    if type(v) ~= "table" or #v ~= Curve.LEVELS then return false end
    for i = 1, Curve.LEVELS do
        if type(v[i]) ~= "number" then return false end
    end
    return true
end

-- Every per-level row in a blueprint, as { path, values }, path being a dotted trail for the report.
local function eachRow(def, fn)
    local function walk(t, path)
        for _, k in ipairs(sortedKeys(t)) do
            local v = t[k]
            local here = path .. "." .. k
            if isCurveRow(v) then
                fn(here, v)
            elseif type(v) == "table" then
                walk(v, here)
            end
        end
    end
    for _, name in ipairs(CONTAINERS) do
        if type(def[name]) == "table" then walk(def[name], name) end
    end
end

-- Every NUMBER an instantiated item carries, as ordered "path = value" lines. Deliberately wider than
-- eachRow: the snapshot should catch an unintended change anywhere in the item, not only in the rows
-- this tool set out to touch.
local function eachNumber(inst, fn)
    local function walk(t, path)
        for _, k in ipairs(sortedKeys(t)) do
            local v = t[k]
            local here = path .. "." .. k
            if type(v) == "number" then
                fn(here, v)
            elseif type(v) == "table" then
                walk(v, here)
            end
        end
    end
    for _, name in ipairs(CONTAINERS) do
        if type(inst[name]) == "table" then walk(inst[name], name) end
    end
end

-- ---------------------------------------------------------------------------
-- Fitting
-- ---------------------------------------------------------------------------

local function sameRow(a, b)
    for i = 1, Curve.LEVELS do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- The generator call that reproduces `values` exactly, as source text -- or nil if neither style
-- does, which is the signal to leave the row alone. The top is dropped when it is simply twice the
-- base, since that is what the one-argument form means.
local function fit(values)
    local base, top = values[1], values[Curve.LEVELS]
    for _, style in ipairs({ "ramp", "paired" }) do
        if sameRow(Curve[style](base, top), values) then
            if top == base * 2 and sameRow(Curve[style](base), values) then
                return "Curve." .. style .. "(" .. base .. ")"
            end
            return "Curve." .. style .. "(" .. base .. ", " .. top .. ")"
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Source rewriting
-- ---------------------------------------------------------------------------

-- A Lua pattern matching this row written out as a literal list, tolerant of the spacing and the
-- optional trailing comma blueprints vary on. Built from the row's own numbers, so it cannot match
-- some other list that merely lives nearby.
local function literalPattern(values)
    local parts = {}
    for i = 1, Curve.LEVELS do
        parts[#parts + 1] = (tostring(values[i]):gsub("%-", "%%-"))
    end
    return "%{%s*" .. table.concat(parts, "%s*,%s*") .. "%s*,?%s*%}"
end

local function sourcePath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

local function readFile(rel)
    local f = io.open(sourcePath(rel), "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local function writeFile(rel, text)
    -- Never write a blueprint that would not parse -- the rewriter edits source text, so this is the
    -- one guard between a bad pattern and a broken data file.
    local ok, err = loadstring(text)
    assert(ok, "refusing to write invalid Lua to " .. rel .. ": " .. tostring(err))
    local f = assert(io.open(sourcePath(rel), "wb"))
    f:write(text)
    f:close()
end

-- The level ruler a hand-typed row needs and a generated one does not:
--     --        level:  0  1  2  3  4  5  6  7  8  9  10
-- Stripped only from a file with no literal rows left, since a surviving literal still wants it.
-- Matches from the newline BEFORE the ruler through to just before the next one, so on a CRLF tree
-- the removed line's own "\r" goes with it and the surviving "\r\n" still separates its neighbours.
-- Spaced with [ \t] rather than %s so the run of level numbers cannot be matched across a line break.
local RULER = "\n[ \t]*%-%-[^\n]-level:[ \t]*0[ \t]+1[ \t]+2[^\n]*"

-- Blueprints load this at file scope, which is safe because models/curve.lua requires nothing.
local REQUIRE_LINE = 'local Curve = require("models.curve")'

-- The line ending this file already uses. The tree is checked out with CRLF (core.autocrlf), so an
-- inserted "\n" would leave the blueprint mixed -- invisible in a diff, and a needless line-ending
-- churn for the next person who touches it.
local function newlineOf(text)
    return text:find("\r\n") and "\r\n" or "\n"
end

local function ensureRequire(text)
    if text:find("models%.curve") then return text end
    local nl = newlineOf(text)
    local inserted = REQUIRE_LINE .. nl .. nl .. "return {"
    -- Most blueprints open with a header comment, so the table's `return {` has a newline in front of
    -- it; a few (ability_fireball, weapon_iron_bow) start with it on line 1 and need the other case.
    if text:find("^return%s*{") then
        return (text:gsub("^return%s*{", (inserted:gsub("%%", "%%%%")), 1))
    end
    local out, n = text:gsub("\r?\nreturn%s*{", (nl .. inserted:gsub("%%", "%%%%")), 1)
    if n == 0 then return nil end
    return out
end

-- ---------------------------------------------------------------------------
-- Item files
-- ---------------------------------------------------------------------------

-- Every blueprint under data/items, as { id, rel }. Recurses exactly as models/registry.lua does, so
-- the id is the bare filename and only the path follows the folder nesting.
local function itemFiles()
    local out = {}
    local function scan(dir)
        for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local path = dir .. "/" .. file
            local info = love.filesystem.getInfo(path)
            if info and info.type == "directory" then
                scan(path)
            else
                local id = file:match("^(.+)%.lua$")
                if id then out[#out + 1] = { id = id, rel = path } end
            end
        end
    end
    scan("data/items")
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- ---------------------------------------------------------------------------
-- Snapshot
-- ---------------------------------------------------------------------------

local function snapshot(outPath)
    local lines = {}
    for _, it in ipairs(itemFiles()) do
        if Item.defs[it.id] then
            for level = 0, Item.MAX_LEVEL do
                local ok, inst = pcall(Item.instantiate, it.id, 1, level)
                if ok and inst then
                    eachNumber(inst, function(path, value)
                        lines[#lines + 1] = it.id .. " @" .. level .. " " .. path .. " = " .. value
                    end)
                else
                    lines[#lines + 1] = it.id .. " @" .. level .. " <instantiate failed>"
                end
            end
        end
    end
    local text = table.concat(lines, "\n") .. "\n"
    local f = assert(io.open(outPath, "wb"))
    f:write(text)
    f:close()
    print("wrote " .. #lines .. " magnitude readings to " .. outPath)
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

function M.run(args)
    args = args or {}
    local mode = args[1]

    if mode == "snapshot" then
        snapshot(args[2] or (love.filesystem.getSource() .. "/curve-snapshot.txt"))
        return
    end

    local apply = (mode == "apply")
    local migrated, kept, files, missed = 0, 0, 0, 0
    local literals = {}

    for _, it in ipairs(itemFiles()) do
        local def = Item.defs[it.id]
        if def then
            local rows = {}
            eachRow(def, function(path, values) rows[#rows + 1] = { path = path, values = values } end)
            if #rows > 0 then
                local text = readFile(it.rel)
                local changed = 0
                local leftLiteral = 0
                -- Two rows in one file can be spelled identically (chainmail's slash and pierce
                -- resists are the same eleven numbers), and one gsub rewrites both. Remembering which
                -- literals have gone keeps the second row from being reported as unfindable.
                local rewritten = {}
                for _, row in ipairs(rows) do
                    local call = fit(row.values)
                    local sig = table.concat(row.values, ",")
                    if not call then
                        leftLiteral = leftLiteral + 1
                        kept = kept + 1
                        literals[#literals + 1] = it.id .. "  " .. row.path
                            .. "  { " .. table.concat(row.values, ", ") .. " }"
                    elseif rewritten[sig] then
                        migrated = migrated + 1
                    elseif text then
                        local replaced, n = text:gsub(literalPattern(row.values), call)
                        if n > 0 then
                            text = replaced
                            rewritten[sig] = true
                            changed = changed + n
                            migrated = migrated + 1
                        else
                            -- Found in the model but not in the text: an unusual literal spelling.
                            -- Left alone, exactly like a row no generator matched.
                            leftLiteral = leftLiteral + 1
                            missed = missed + 1
                        end
                    end
                end
                if changed > 0 and text then
                    if leftLiteral == 0 then text = (text:gsub(RULER, "")) end
                    local withRequire = ensureRequire(text)
                    if withRequire then
                        files = files + 1
                        if apply then writeFile(it.rel, withRequire) end
                    else
                        print("SKIPPED " .. it.rel .. " -- no `return {` to hang the require on")
                    end
                end
            end
        end
    end

    print("")
    print((apply and "rewrote " or "would rewrite ") .. migrated .. " rows across " .. files .. " files")
    print(kept .. " rows keep their literal list (no generator reproduces them exactly)")
    if missed > 0 then
        print(missed .. " rows matched a generator but were not found in source -- left literal")
    end
    if not apply then
        print("")
        print("-- rows staying literal --")
        for _, line in ipairs(literals) do print("  " .. line) end
        print("")
        print("re-run with `apply` to write the changes")
    end
end

return M
