-- Dev-only: write a live character back out as a data/characters/<id>.lua blueprint, so the debug
-- character editor (states/debug_editor.lua) can promote something built in-game into real, committed
-- content.
--
-- This is the inverse of Character.instantiate, and instantiate is LOSSY in three places -- each undone
-- here, each with a test in tests/character_writer_spec.lua:
--
--   sprite/portrait  the runtime fields are Sprite objects that no longer know their path, so we read
--                    the `spritePath`/`portraitPath` that Character.instantiate keeps beside them
--   stats            resource stats live as { max, current } at runtime, and `max` carries accumulated
--                    level-up growth; the blueprint wants the flat BASE, i.e. max minus growth
--   defaultAction    the runtime holds a cell INDEX (defaultActionSlot); the blueprint names an item id
--
-- The emitter is hand-rolled rather than generic on purpose. models/save.lua's `encode` sorts keys and
-- emits ["stats"] = {...}, which would reformat data/characters/*.lua unrecognizably; these files are
-- read and hand-edited far more often than they are generated, so the output has to look like the
-- neighbours it lands beside. Key order below is the authored order those files already use.
--
--   local ok, err = Writer.write(char)

local Character = require("models.character")

local M = {}

-- Emitted in this order; anything the character carries outside the list is dropped, which is the same
-- contract Character.instantiate has in the other direction (a field nobody names does not survive).
local STAT_ORDER = {
    "health", "mana", "stamina",
    "staminaRegen",
    "damage", "magicDamage",
    "defense", "magicDefense",
    "movement", "speed",
}

-- Rule keys in the order ui/tactics_editor.lua presents them, so a rule reads down the file the way it
-- reads down the editor.
local RULE_ORDER = { "enabled", "priority", "act", "item", "targetPref" }
local WHEN_ORDER = { "subject", "test", "value" }

local RESOURCE = {}
for _, key in ipairs(Character.RESOURCE_STATS) do RESOURCE[key] = true end

-- A double-quoted Lua string literal, escaping the structural characters and passing UTF-8 bytes
-- through unchanged (a character named in Japanese stays readable in the file). Same helper, same
-- reasoning, as tools/extract_strings.lua.
local function q(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return "\"" .. s .. "\""
end

-- A scalar as Lua source. Rules and stats only ever hold these three types; anything else is an
-- authoring mistake worth failing loudly on rather than writing a broken file about.
local function scalar(v)
    local t = type(v)
    if t == "string" then return q(v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    error("cannot serialize a " .. t .. " into a character blueprint")
end

-- The BASE value of `key` on `char` -- runtime shape unwrapped, level-up growth removed. Writing the
-- levelled number would bake a character's progress into the blueprint permanently, so every stat goes
-- through here rather than being read off char.stats directly.
function M.baseStat(char, key)
    local live = char.stats and char.stats[key]
    if live == nil then return nil end
    local value = RESOURCE[key] and live.max or live
    if type(value) ~= "number" then return nil end
    return value - ((char.growth and char.growth[key]) or 0)
end

local function serializeStats(char, out)
    local seen = {}
    local lines = {}
    for _, key in ipairs(STAT_ORDER) do
        seen[key] = true
        local value = M.baseStat(char, key)
        if value then lines[#lines + 1] = "        " .. key .. " = " .. scalar(value) .. "," end
    end
    -- A stat outside STAT_ORDER still gets written -- silently dropping one would be the exact failure
    -- mode the "copied explicitly" comment in Character.instantiate warns about. Sorted, since pairs
    -- has no order and this file must not shuffle between runs.
    local extra = {}
    for key in pairs(char.stats or {}) do
        if not seen[key] then extra[#extra + 1] = key end
    end
    table.sort(extra)
    for _, key in ipairs(extra) do
        local value = M.baseStat(char, key)
        if value then lines[#lines + 1] = "        " .. key .. " = " .. scalar(value) .. "," end
    end

    out[#out + 1] = "    stats = {\n"
    out[#out + 1] = table.concat(lines, "\n") .. "\n"
    out[#out + 1] = "    },\n"
end

-- The 3x3 grid, positionally, row-major, three per line -- the shape the Loadout screen shows and the
-- shape every hand-authored blueprint already uses. Every cell is emitted (`false` for a gap) so the
-- rows line up as a readable grid rather than collapsing.
local function serializeItems(char, out)
    out[#out + 1] = "    startingItems = {\n"
    for row = 0, Character.ROWS - 1 do
        local cells = {}
        for col = 1, Character.COLS do
            local item = char.inventory and char.inventory[row * Character.COLS + col]
            if not item then
                cells[#cells + 1] = "false"
            elseif (item.quantity or 1) > 1 then
                cells[#cells + 1] = "{ " .. q(item.id) .. ", " .. tostring(item.quantity) .. " }"
            else
                cells[#cells + 1] = q(item.id)
            end
        end
        out[#out + 1] = "        " .. table.concat(cells, ", ") .. ",\n"
    end
    out[#out + 1] = "    },\n"
end

local function serializeRule(rule)
    -- `whenFn` is a closure escape hatch for NPC-only content (models/ai.lua). A function cannot
    -- survive a round trip through a text file, and writing the rule without it would silently change
    -- what the rule MEANS -- so refuse rather than corrupt.
    assert(rule.whenFn == nil, "a rule with a whenFn cannot be written to a blueprint")

    local parts = {}
    for _, key in ipairs(RULE_ORDER) do
        if rule[key] ~= nil then parts[#parts + 1] = key .. " = " .. scalar(rule[key]) end
    end
    if rule.when then
        local when = {}
        for _, key in ipairs(WHEN_ORDER) do
            if rule.when[key] ~= nil then when[#when + 1] = key .. " = " .. scalar(rule.when[key]) end
        end
        parts[#parts + 1] = "when = { " .. table.concat(when, ", ") .. " }"
    end
    return "        { " .. table.concat(parts, ", ") .. " },\n"
end

-- Blueprint-authored rules. The editor writes the player-source list (`char.aiRules`, the Tactics tab),
-- but a blueprint has only ONE rule channel -- `ai` -- so the two are concatenated on the way out.
-- Reloading the written file brings them back as blueprint rules, which is the intended promotion: a
-- rule list authored in the editor becomes the character's own.
local function serializeAI(char, out)
    local rules = {}
    for _, rule in ipairs(char.ai or {}) do rules[#rules + 1] = rule end
    for _, rule in ipairs(char.aiRules or {}) do rules[#rules + 1] = rule end
    if #rules == 0 then return end

    out[#out + 1] = "    ai = {\n"
    for _, rule in ipairs(rules) do out[#out + 1] = serializeRule(rule) end
    out[#out + 1] = "    },\n"
end

-- The whole blueprint as Lua source. Pure -- no love, no io -- so the round trip is unit-testable.
function M.serialize(char)
    local out = { "-- Generated by the debug character editor (states/debug_editor.lua).\nreturn {\n" }

    out[#out + 1] = "    name = " .. q(char.name or char.id) .. ",\n"
    if char.spritePath then out[#out + 1] = "    sprite = " .. q(char.spritePath) .. ",\n" end
    if char.portraitPath then out[#out + 1] = "    portrait = " .. q(char.portraitPath) .. ",\n" end
    if char.class then out[#out + 1] = "    class = " .. q(char.class) .. ",\n" end
    if char.archetype then out[#out + 1] = "    archetype = " .. q(char.archetype) .. ",\n" end
    if char.boss then out[#out + 1] = "    boss = true,\n" end

    -- `unarmed` is three-valued and only two of them are worth writing: nil means "this body has no
    -- natural weapon" (blueprint `false`), and a non-default id is an authored choice. The default is
    -- omitted, because that is what an absent field already means.
    if char.unarmed == nil then
        out[#out + 1] = "    unarmed = false,\n"
    elseif char.unarmed.id ~= Character.DEFAULT_UNARMED then
        out[#out + 1] = "    unarmed = " .. q(char.unarmed.id) .. ",\n"
    end

    serializeStats(char, out)
    serializeItems(char, out)

    local pinned = char.defaultActionSlot and char.inventory and char.inventory[char.defaultActionSlot]
    if pinned then out[#out + 1] = "    defaultAction = " .. q(pinned.id) .. ",\n" end

    serializeAI(char, out)

    out[#out + 1] = "}\n"
    return table.concat(out)
end

-- Write `char` to data/characters/<char.id>.lua in the PROJECT SOURCE TREE, so the result can be
-- hand-edited and committed. Returns ok, err.
--
-- love.filesystem.write can only reach the save directory, so this goes through a raw io.open on the
-- source path -- the same dev-only route Arena.save (models/arena.lua) and tools/extract_strings.lua
-- already take, and like them it only works running unfused from source (`love .`).
function M.write(char)
    assert(char and char.id, "write_character: need a character with an id")

    local text = M.serialize(char)

    -- Validate BEFORE touching the disk: a serializer bug must never land broken Lua in data/, where
    -- it would take the whole registry down on next launch. Borrowed from tools/extract_strings.lua.
    local loader = loadstring or load
    local chunk, err = loader(text)
    if not chunk then return false, "refusing to write invalid Lua: " .. tostring(err) end

    if not (love and love.filesystem and love.filesystem.getSource) then
        return false, "love.filesystem unavailable"
    end
    local rel = "data/characters/" .. char.id .. ".lua"
    local path = love.filesystem.getSource() .. "/" .. rel
    local file = io.open(path, "wb")
    if not file then return false, "could not open " .. rel .. " (dev-only; run unfused from source)" end
    file:write(text)
    file:close()

    -- Keep the running session and the file in agreement: the registry was loaded at startup and would
    -- otherwise still hold the pre-edit blueprint (or nothing at all, for a character just minted).
    Character.defs[char.id] = chunk()

    return true, rel
end

return M
