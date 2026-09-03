-- THE CLASS FOLD, as a data pass: `& "E:\LOVE\lovec.exe" . class-fold [creature] [apply]`
--
-- Collapses the two taxonomies onto one. See docs/class-fold.md for why; this is the mechanics.
--
--   default    the 290 items carrying both fields. The `class` line is DELETED and the `discipline`
--              line is RENAMED to `class` -- deliberately that way round rather than rewriting the
--              class value and deleting the discipline line, because 182 of those discipline lines
--              carry an authored trailing comment explaining the choice ("rogue x priest; Judgment --
--              the naming that holds a body open for the execute") and that rationale is exactly what
--              the surviving field wants attached to it. The two lines are adjacent in 288 of 290
--              files, so the field also keeps its seat.
--
--   creature   the items carrying NEITHER field -- natural weapons, a demon's own art, the machinery a
--              boss runs its phases on. Seats `class = "creature"` after `type`.
--
-- Dry run by default: prints what it would do and writes nothing.
--
-- Byte-exact: files are read and written "rb"/"wb" so a CRLF tree stays a CRLF tree. A stream editor
-- run over this repo rewrites every line ending in every file it touches, which buries a two-line
-- change in a two-thousand-line diff.

local Item = require("models.item")

local M = {}

local KINDS = { "weapon", "armor", "utility", "consumable", "ability" }

local function pathOf(id)
    for _, kind in ipairs(KINDS) do
        local p = "data/items/" .. kind .. "/" .. id .. ".lua"
        local f = io.open(p, "rb")
        if f then f:close(); return p end
    end
    return nil
end

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local src = f:read("*a")
    f:close()
    return src
end

local function write(path, src)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(src)
    f:close()
    return true
end

-- `[ \t]*` rather than `%s*` throughout: `%s` matches a newline, so an anchored `\n%s*class` can eat
-- the blank line above and take the field's own newline with it, silently joining two unrelated lines.
local CLASS_LINE = "\n[ \t]*class[ \t]*=[^\n]*"
local DISC_LINE = "(\n[ \t]*)discipline([ \t]*=)"
local TYPE_LINE = "(\n[ \t]*type[ \t]*=[^\n]*\n)"

-- ---------------------------------------------------------------------------
-- The move: discipline becomes the class
-- ---------------------------------------------------------------------------

function M.planMove()
    local rows = {}
    for id, def in pairs(Item.defs) do
        if def.discipline then
            rows[#rows + 1] = { id = id, from = def.class, to = def.discipline }
        end
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

local function rewriteMove(id)
    local path = pathOf(id)
    if not path then return false, "no file" end
    local src = read(path)
    if not src then return false, "unreadable" end

    local _, classes = src:gsub(CLASS_LINE, "")
    local _, discs = src:gsub(DISC_LINE, "%1class%2")
    if classes ~= 1 then return false, classes .. " class lines" end
    if discs ~= 1 then return false, discs .. " discipline lines" end

    local out = src:gsub(CLASS_LINE, "", 1)
    out = out:gsub(DISC_LINE, "%1class%2", 1)
    if out == src then return false, "no change" end
    return write(path, out)
end

-- ---------------------------------------------------------------------------
-- The bucket: kit that belongs to no job
-- ---------------------------------------------------------------------------

function M.planCreature()
    local rows = {}
    for id, def in pairs(Item.defs) do
        if not def.class and not def.discipline then rows[#rows + 1] = { id = id } end
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

local function rewriteCreature(id)
    local path = pathOf(id)
    if not path then return false, "no file" end
    local src = read(path)
    if not src then return false, "unreadable" end
    if src:match(CLASS_LINE) then return false, "already has a class" end

    -- Seated after `type`, which is the field it reads next to: one says what kind of thing this is,
    -- the other whose job it is.
    local out, n = src:gsub(TYPE_LINE, '%1    class = "creature",\n', 1)
    if n ~= 1 then return false, "no type line to seat it after" end
    return write(path, out)
end

-- ---------------------------------------------------------------------------
-- The gates: `classes` and `requiredLevel` become one `requires`
-- ---------------------------------------------------------------------------
--
-- A class blueprint carried its parents in one field and its gate in another, and the two could not be
-- reconciled by machine: every crossing named TWO parents and gated on ONE of them, with the other half
-- of the requirement living as an implicit rule in Class.isUnlocked ("hold a subclass of each
-- parent"). Thirty-two of the thirty-eight gates were marked `-- pending` on top of that.
--
-- SO THE SECOND HALF IS AUTHORED HERE, AT THE LEVEL THE FIRST ALREADY SAID. A crossing asks the same
-- depth of both houses it is cut from -- there is no primary parent, and inventing one would be a
-- design decision smuggled in as a migration. Every rung stays inside the three-classes-per-rung
-- ceiling tests/class_ladder_spec enforces; the worst are rogue 6, rogue 7, fighter 7, hunter 8,
-- alchemist 8 and mage 8, each opening exactly three.
--
-- A ROOT loses both fields outright: nothing stands above it and nothing gates it.

local function fmtRequires(pairsList)
    local parts = {}
    for _, kv in ipairs(pairsList) do
        parts[#parts + 1] = kv[1] .. " = " .. kv[2]
    end
    return "    requires = { " .. table.concat(parts, ", ") .. " },"
end

-- Answers nothing once the pass has run: with `classes` gone there are no parents to read, every row
-- comes back a root, and rewriteGate finds nothing to replace. Kept rather than deleted because the
-- three modes here are one migration and the file is its record -- and because step 5 wants the same
-- file-rewriting spine (docs/class-fold.md).
function M.planGates()
    local Class = require("models.class")
    local rows = {}
    for id, def in pairs(Class.defs) do
        local parents = def.classes or {}
        local want = {}
        if #parents > 0 then
            -- The authored level, whichever parent it was hung on, applied to every parent.
            local level
            for _, n in pairs(def.requiredLevel or {}) do level = math.max(level or 0, n) end
            for _, p in ipairs(parents) do
                want[#want + 1] = { p, (def.requiredLevel or {})[p] or level or 3 }
            end
        end
        rows[#rows + 1] = { id = id, requires = want, root = #parents == 0 }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

local function rewriteGate(row)
    local path = "data/classes/" .. row.id .. ".lua"
    local src = read(path)
    if not src then return false, "unreadable" end

    -- Both old fields go, whatever order they sit in and whatever trailing comment they carry. The
    -- `-- pending` markers go with them, which is the point: the gate is authored now.
    local out = src:gsub("\n[ \t]*classes[ \t]*=[^\n]*", "", 1)
    if row.root then
        out = out:gsub("\n[ \t]*requiredLevel[ \t]*=[^\n]*", "", 1)
    else
        out = out:gsub("\n[ \t]*requiredLevel[ \t]*=[^\n]*", "\n" .. fmtRequires(row.requires), 1)
        if not out:match("\n[ \t]*requires[ \t]*=") then return false, "no requiredLevel line to replace" end
    end
    if out == src then return false, "no change" end
    return write(path, out)
end

-- ---------------------------------------------------------------------------

function M.run(args)
    local apply, creature, gates = false, false, false
    for _, a in ipairs(args or {}) do
        if a == "apply" then apply = true end
        if a == "creature" then creature = true end
        if a == "gates" then gates = true end
    end

    if gates then
        local rows = M.planGates()
        print("GATES: " .. #rows .. " class blueprint(s)")
        for _, r in ipairs(rows) do
            local bits = {}
            for _, kv in ipairs(r.requires) do bits[#bits + 1] = kv[1] .. " " .. kv[2] end
            print(string.format("  %-16s %s", r.id, r.root and "(root: no gate)" or table.concat(bits, " + ")))
        end
        if not apply then
            print("\nReport only -- nothing was written. Add `apply` to write.")
            return
        end
        local done, failed = 0, {}
        for _, r in ipairs(rows) do
            local ok, why = rewriteGate(r)
            if ok then done = done + 1 else failed[#failed + 1] = r.id .. " (" .. tostring(why) .. ")" end
        end
        print("\nwrote " .. done .. " file(s)")
        if #failed > 0 then print("could not write:\n  " .. table.concat(failed, "\n  ")) end
        return
    end

    local rows = creature and M.planCreature() or M.planMove()
    print((creature and "CREATURE" or "MOVE") .. ": " .. #rows .. " item(s)")

    if not creature then
        local tally = {}
        for _, r in ipairs(rows) do tally[r.to] = (tally[r.to] or 0) + 1 end
        local keys = {}
        for k in pairs(tally) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do print(string.format("  %-16s %d", k, tally[k])) end
    end

    if not apply then
        print("\nReport only -- nothing was written. Add `apply` to write.")
        return
    end

    local done, failed = 0, {}
    for _, r in ipairs(rows) do
        local ok, why = creature and rewriteCreature(r.id) or rewriteMove(r.id)
        if ok then done = done + 1 else failed[#failed + 1] = r.id .. " (" .. tostring(why) .. ")" end
    end
    print("\nwrote " .. done .. " file(s)")
    if #failed > 0 then print("could not write:\n  " .. table.concat(failed, "\n  ")) end
end

return M
