-- String-extraction tool (the "Yarn Spinner" step): run with
--
--     & "E:\LOVE\lovec.exe" . extract-strings
--
-- It does three things, so authors write only inline English and translators get clean ID-keyed
-- files:
--   1. Stamps a STABLE localization `tag` into every conversation line/choice that lacks one, then
--      rewrites the conversation file. Tags persist in the file, so they survive editing the English
--      and reordering lines -- the whole point of stable ids.
--   2. Regenerates data/lang/en.lua -- the id -> English TEMPLATE (a translator's reference; the game
--      never reads it at runtime, since English is authored inline).
--   3. Merges every other data/lang/<lang>.lua: keeps existing translations, carries a legacy
--      source-text-keyed translation over to its new id, and adds any new ids as `TODO` with the
--      current English shown in an `-- EN:` comment.
--
-- Writes into the PROJECT source tree (not the LOVE save dir), so it uses io.open with absolute paths
-- built from love.filesystem.getSource(). Every generated file is validated with loadstring before it
-- is written, so a serializer bug can never leave a broken .lua on disk.

local Character = require("models.character")
local Vendor = require("models.vendor")
local Locale = require("models.locale")

local M = {}

-- ---------------------------------------------------------------------------
-- Lua serialization helpers
-- ---------------------------------------------------------------------------

-- A double-quoted Lua string literal. Escapes the structural characters; UTF-8 bytes pass through
-- unchanged (so Japanese is written literally, readable in the file).
local function q(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return "\"" .. s .. "\""
end

local function castId(entry) return type(entry) == "table" and entry.id or entry end
local function nodeSpeaker(n) return n.by or n[1] end
local function nodeText(n) return n.text or n[2] end
local function choiceText(c) return c.text or c[1] end

-- A script entry that groups lines under a shared `when` rather than speaking one (see
-- models/conversation.lua). Blocks nest, so every walk below recurses through them.
local function isBlock(entry) return entry.script ~= nil end

-- Call `fn(node)` for every speaking node in an (optionally nested) script, in authored order.
local function eachNode(entries, fn)
    for _, entry in ipairs(entries or {}) do
        if isBlock(entry) then eachNode(entry.script, fn) else fn(entry) end
    end
end

-- Serialize a `when` condition table. These are pure data (that is WHY conditions are data and not
-- predicate functions -- a closure could not survive this round trip and would be erased here).
-- Keys are emitted in a stable order so re-stamping a file produces no spurious diff.
local WHEN_KEYS = { "has", "notHas", "done", "notDone", "prestige", "all", "any" }
local function serializeWhen(when)
    local parts = {}
    for _, key in ipairs(WHEN_KEYS) do
        local v = when[key]
        if v ~= nil then
            if key == "all" or key == "any" then
                local subs = {}
                for _, sub in ipairs(v) do subs[#subs + 1] = serializeWhen(sub) end
                parts[#parts + 1] = key .. " = { " .. table.concat(subs, ", ") .. " }"
            elseif type(v) == "number" then
                parts[#parts + 1] = key .. " = " .. tostring(v)
            else
                parts[#parts + 1] = key .. " = " .. q(v)
            end
        end
    end
    for key in pairs(when) do
        local known = false
        for _, k in ipairs(WHEN_KEYS) do if k == key then known = true break end end
        assert(known, "cannot serialize unknown `when` condition '" .. tostring(key) .. "'")
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Serialize a choice's `effect` -- the declarative outcome applied when the choice is committed
-- (models/story_effect.lua). Pure data, like `when`, which is what lets it survive this round trip.
-- Keys emitted in a stable order so re-stamping a file produces no spurious diff; an unknown key is a
-- loud error rather than a silent drop.
local EFFECT_KEYS = { "grant", "gold", "heal", "maxHpCost", "restore", "flag" }
local function serializeEffect(effect)
    local parts = {}
    for _, key in ipairs(EFFECT_KEYS) do
        local v = effect[key]
        if v ~= nil then
            if key == "grant" and type(v) == "table" then
                local ids = {}
                for _, id in ipairs(v) do ids[#ids + 1] = q(id) end
                parts[#parts + 1] = key .. " = { " .. table.concat(ids, ", ") .. " }"
            elseif type(v) == "number" or type(v) == "boolean" then
                parts[#parts + 1] = key .. " = " .. tostring(v)
            else
                parts[#parts + 1] = key .. " = " .. q(v)
            end
        end
    end
    for key in pairs(effect) do
        local known = false
        for _, k in ipairs(EFFECT_KEYS) do if k == key then known = true break end end
        assert(known, "cannot serialize unknown `effect` key '" .. tostring(key) .. "'")
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Serialize one choice: { "<text>", tag = N, goto = "..", effect = { .. } }
local function serializeChoice(c)
    local parts = { q(choiceText(c) or "") }
    if c.tag ~= nil then parts[#parts + 1] = "tag = " .. c.tag end
    if c.goto then parts[#parts + 1] = "goto = " .. q(c.goto) end
    if c.effect then parts[#parts + 1] = "effect = " .. serializeEffect(c.effect) end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Serialize one node: { "<speaker>", "<text>", tag = N, id = "..", goto = "..", choices = { .. } }.
-- Nodes are one line; a node with choices spans lines with the choices indented under it. `indent`
-- is the leading whitespace for this nesting depth (a node inside a block sits one level deeper).
local function serializeNode(n, indent)
    local parts = { q(nodeSpeaker(n) or ""), q(nodeText(n) or "") }
    if n.tag ~= nil then parts[#parts + 1] = "tag = " .. n.tag end
    if n.id then parts[#parts + 1] = "id = " .. q(n.id) end
    if n.name then parts[#parts + 1] = "name = " .. q(n.name) end
    if n.portrait then parts[#parts + 1] = "portrait = " .. q(n.portrait) end
    if n.goto then parts[#parts + 1] = "goto = " .. q(n.goto) end
    if n.when then parts[#parts + 1] = "when = " .. serializeWhen(n.when) end
    local head = indent .. "{ " .. table.concat(parts, ", ")
    if n.choices then
        local lines = { head .. ", choices = {" }
        for _, c in ipairs(n.choices) do
            lines[#lines + 1] = indent .. "    " .. serializeChoice(c) .. ","
        end
        lines[#lines + 1] = indent .. "} },"
        return table.concat(lines, "\n")
    end
    return head .. " },"
end

-- Serialize a script (nodes and nested conditional blocks) into `out`, one entry per element.
local function serializeScript(entries, indent, out)
    for _, entry in ipairs(entries or {}) do
        if isBlock(entry) then
            out[#out + 1] = indent .. "{ when = " .. serializeWhen(entry.when or {}) .. ", script = {"
            serializeScript(entry.script, indent .. "    ", out)
            out[#out + 1] = indent .. "} },"
        else
            out[#out + 1] = serializeNode(entry, indent)
        end
    end
end

-- Serialize a cast entry: a bare id string, or a table when it carries overrides (`when`, an
-- ad-hoc name/portrait, an explicit slot). Collapsing a table entry to its id -- as this once did
-- -- would quietly drop the very condition that keeps an unrecruited character off the stage.
local function serializeCastEntry(e)
    if type(e) ~= "table" then return q(e) end
    local parts = { "id = " .. q(e.id) }
    if e.name then parts[#parts + 1] = "name = " .. q(e.name) end
    if e.portrait then parts[#parts + 1] = "portrait = " .. q(e.portrait) end
    if e.slot then parts[#parts + 1] = "slot = " .. tostring(e.slot) end
    if e.when then parts[#parts + 1] = "when = " .. serializeWhen(e.when) end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Serialize a whole conversation def back to a readable .lua file.
local function serializeConversation(def)
    local out = {}
    out[#out + 1] = "-- Conversation authored inline (English); localization ids (`tag`) are stamped by"
    out[#out + 1] = "-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua."
    out[#out + 1] = "return {"
    if def.title then out[#out + 1] = "    title = " .. q(def.title) .. "," end
    local cast = {}
    for _, e in ipairs(def.cast or {}) do cast[#cast + 1] = serializeCastEntry(e) end
    out[#out + 1] = "    cast  = { " .. table.concat(cast, ", ") .. " },"
    out[#out + 1] = ""
    out[#out + 1] = "    script = {"
    serializeScript(def.script, "        ", out)
    out[#out + 1] = "    },"
    out[#out + 1] = "}"
    out[#out + 1] = ""
    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- Filesystem (writes into the project source tree via io, not the LOVE save dir)
-- ---------------------------------------------------------------------------

local function sourcePath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

local function writeFile(rel, text)
    -- Never write a file that would not parse -- guards against a serializer bug.
    local ok, err = loadstring(text)
    assert(ok, "refusing to write invalid Lua to " .. rel .. ": " .. tostring(err))
    local f = assert(io.open(sourcePath(rel), "wb"))
    f:write(text)
    f:close()
end

local function conversationIds()
    local ids = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems("data/conversations")) do
        local id = file:match("^(.+)%.lua$")
        if id then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

-- ---------------------------------------------------------------------------
-- Extraction
-- ---------------------------------------------------------------------------

-- Assign a stable integer tag to every node/choice that lacks one (the next unused value, so existing
-- tags are never disturbed). Returns true if anything was newly stamped.
local function stampTags(def)
    local used, maxTag = {}, 0
    local function note(t) if type(t) == "number" then used[t] = true; if t > maxTag then maxTag = t end end end
    eachNode(def.script, function(n)
        note(n.tag)
        for _, c in ipairs(n.choices or {}) do note(c.tag) end
    end)
    local changed = false
    local function assign(entry)
        if entry.tag == nil then
            maxTag = maxTag + 1
            entry.tag = maxTag
            changed = true
        end
    end
    eachNode(def.script, function(n)
        assign(n)
        for _, c in ipairs(n.choices or {}) do assign(c) end
    end)
    return changed
end

-- All translatable strings for one conversation, as ordered { key, en } records: the title, every
-- line and choice (keyed by its stamped tag), and each distinct speaker's name.
--
-- This reads the AUTHORED def, never a resolved one, so conditions are deliberately ignored here:
-- a translator gets every line the scene can ever show, including the priest's, regardless of who
-- happens to be recruited in whatever save was last played.
local function collect(convId, def, out, seenNames)
    if def.title then
        out[#out + 1] = { key = Locale.key.title(convId), en = def.title }
    end
    eachNode(def.script, function(n)
        out[#out + 1] = { key = Locale.key.line(convId, n.tag), en = nodeText(n) or "" }
        for _, c in ipairs(n.choices or {}) do
            out[#out + 1] = { key = Locale.key.line(convId, c.tag), en = choiceText(c) or "" }
        end
    end)
    -- Speaker names (from the cast and any `by`), de-duplicated across the whole run.
    local function noteName(id)
        if not id or seenNames[id] then return end
        seenNames[id] = true
        local d = Character.defs[id] or Vendor.defs[id]
        if d and d.name then out[#out + 1] = { key = Locale.key.name(id), en = d.name } end
    end
    for _, e in ipairs(def.cast or {}) do noteName(castId(e)) end
    eachNode(def.script, function(n) noteName(nodeSpeaker(n)) end)
end

-- Load the translations already on disk as cells[key][lang] = value, plus the sorted list of the
-- non-English languages found. Reads the grid (data/lang/strings.lua) when it exists, and ALSO folds
-- in any legacy per-language file (data/lang/<lang>.lua, the pre-grid format) so the first run after
-- the migration carries every existing translation across. English cells are ignored here -- the
-- `en` column is regenerated from the inline source, never preserved.
local function loadExistingCells()
    local cells, langSet = {}, {}
    local function put(key, lang, value)
        if lang == Locale.DEFAULT or type(value) ~= "string" then return end
        cells[key] = cells[key] or {}
        if cells[key][lang] == nil then cells[key][lang] = value end
        langSet[lang] = true
    end

    local ok, gridTbl = pcall(require, "data.lang.strings")
    if ok and type(gridTbl) == "table" then
        for key, row in pairs(gridTbl) do
            if type(row) == "table" then
                for lang, v in pairs(row) do put(key, lang, v) end
            end
        end
    end
    for _, file in ipairs(love.filesystem.getDirectoryItems("data/lang")) do
        local lang = file:match("^(.+)%.lua$")
        if lang and lang ~= "strings" and lang ~= Locale.DEFAULT then
            local lok, flat = pcall(require, "data.lang." .. lang)
            if lok and type(flat) == "table" then
                for key, v in pairs(flat) do put(key, lang, v) end
            end
        end
    end

    local list = {}
    for l in pairs(langSet) do list[#list + 1] = l end
    table.sort(list)
    return cells, list
end

-- Serialize the grid: one row per id, columns en (mirror of the inline source) then each translation
-- language, keeping existing cells and blanking new ones (flagged `-- TODO`). Rows are sorted by id.
local function serializeGrid(records, cells, otherLangs)
    -- De-dupe records into an id -> English map (title/line/name ids are already unique) and sort.
    local enByKey, keys, seen = {}, {}, {}
    for _, r in ipairs(records) do
        if not seen[r.key] then seen[r.key] = true; keys[#keys + 1] = r.key; enByKey[r.key] = r.en end
    end
    table.sort(keys)

    local out = {}
    out[#out + 1] = "-- GENERATED/MERGED by tools/extract_strings.lua -- the localization grid: one row per"
    out[#out + 1] = "-- string id, a column per language. `en` mirrors the inline English source (do not edit"
    out[#out + 1] = "-- here -- edit the conversation/blueprint); translate the other columns. A blank cell (or"
    out[#out + 1] = "-- `-- TODO`) falls back to English at runtime. See docs/localization.md."
    out[#out + 1] = "return {"
    for _, key in ipairs(keys) do
        local parts = { "en = " .. q(enByKey[key]) }
        local todo = false
        for _, lang in ipairs(otherLangs) do
            local v = (cells[key] and cells[key][lang]) or ""
            if v == "" then todo = true end
            parts[#parts + 1] = lang .. " = " .. q(v)
        end
        out[#out + 1] = "    [" .. q(key) .. "] = { " .. table.concat(parts, ", ") .. " },"
            .. (todo and "  -- TODO" or "")
    end
    out[#out + 1] = "}"
    out[#out + 1] = ""
    return table.concat(out, "\n")
end

function M.run()
    print("extract-strings: source = " .. tostring(love.filesystem.getSource()))
    local records, seenNames = {}, {}
    local stamped = 0

    for _, convId in ipairs(conversationIds()) do
        local def = require("data.conversations." .. convId)
        if stampTags(def) then
            writeFile("data/conversations/" .. convId .. ".lua", serializeConversation(def))
            stamped = stamped + 1
        end
        collect(convId, def, records, seenNames)
    end

    local cells, otherLangs = loadExistingCells()
    writeFile("data/lang/strings.lua", serializeGrid(records, cells, otherLangs))

    -- Migrate away the old per-language files (folded into the grid above). os.remove is a no-op once
    -- they are gone, so this is safe on every run.
    os.remove(sourcePath("data/lang/en.lua"))
    for _, lang in ipairs(otherLangs) do os.remove(sourcePath("data/lang/" .. lang .. ".lua")) end

    print(string.format("extract-strings: %d string(s) across %d conversation(s); stamped %d file(s); languages: %s.",
        #records, #conversationIds(), stamped, table.concat(otherLangs, ", ")))
end

return M
