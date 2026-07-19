-- Blueprint field editor: the numbers and the identity of ONE character, edited live. Lives on the
-- debug character editor's third tab (states/debug_editor.lua, via ui/panels/party.lua's `stats`
-- option) and is never part of the shipped Loadout screen -- these are authoring controls, not
-- settings a player is meant to reach.
--
-- It edits exactly the fields that survive a round trip into data/characters/<id>.lua
-- (tools/write_character.lua). That is the whole design constraint: a control here with no
-- counterpart in the writer would let someone spend an afternoon on a value that silently vanishes
-- the moment they saved. `archetype` is deliberately ABSENT -- the Tactics tab already owns it, and
-- two editors for one field is a disagreement waiting to happen.
--
-- Two regions, crossed with Tab / Y (the same contract ui/tactics_editor.lua implements, so the
-- panel can drive either without knowing which it has):
--
--   stats     the ten numbers, stepped with left/right (hold Shift for 10)
--   identity  name, class, boss, natural weapon, and the two art paths -- cycled with left/right
--
--   local ed = StatEditor.new({ x, y, w, h, char = char, fonts = { ... }, onEditName = fn })

local Character = require("models.character")
local Item = require("models.item")
local InputMode = require("input_mode")

local StatEditor = {}
StatEditor.__index = StatEditor

local ROW_H = 30
local ROW_GAP = 6
local ARROW_W = 18
-- The right-hand zone every row reserves for "< value >". Fixed, so the values line up down the
-- column, and wide enough for an item name -- a blueprint id like "weapon_unarmed" wrapped to two
-- lines and ran under the arrows when this was sized for a two-digit stat.
local VALUE_W = 170

local C_ROW      = { 0.17, 0.18, 0.24 }
local C_ROW_SEL  = { 0.24, 0.27, 0.36 }
local C_TEXT     = { 0.86, 0.88, 0.94 }
local C_TEXT_OFF = { 0.46, 0.48, 0.54 }
local C_ACCENT   = { 0.98, 0.82, 0.30 }
local C_DIM      = { 0.62, 0.65, 0.74 }

local function setColor(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

-- Stats are capped well above anything the game ships so a typo is recoverable by holding the other
-- arrow, and floored at 0 rather than 1 -- a body with 0 damage is a legitimate thing to author.
local STAT_MIN, STAT_MAX = 0, 999

-- Sorted so the list cannot shuffle between runs (pairs has no order).
local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Every file under `dir`, as an asset path, with `false` first so "no art" stays reachable. Read
-- lazily: love.filesystem is absent under the headless test runner.
local function assetPaths(dir)
    local out = { false }
    if not (love and love.filesystem and love.filesystem.getDirectoryItems) then return out end
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        if name:match("%.png$") then out[#out + 1] = dir .. "/" .. name end
    end
    return out
end

-- Candidate natural weapons: `false` (this body cannot strike at all -- the Pig) plus every weapon in
-- the registry, so a blueprint can name fangs, a beak, or the generic fists.
local function unarmedOptions()
    local out = { false }
    local ids = {}
    for id, def in pairs(Item.defs) do
        if def.type == "weapon" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do out[#out + 1] = id end
    return out
end

-- ---------------------------------------------------------------------------
-- Field descriptors
-- ---------------------------------------------------------------------------
--
-- Same idiom as ui/tactics_editor.lua's FIELDS: held as data so the draw loop, the input loop and the
-- tests all walk one definition. Every accessor takes (char).

local STAT_KEYS = {
    "health", "mana", "stamina", "staminaRegen",
    "damage", "magicDamage", "defense", "magicDefense",
    "movement", "speed",
}

local STAT_LABEL = {
    health = "HP", mana = "MP", stamina = "SP", staminaRegen = "SP Regen",
    damage = "Attack", magicDamage = "Magic", defense = "Defense",
    magicDefense = "M.Def", movement = "Move", speed = "Speed",
}

local RESOURCE = {}
for _, key in ipairs(Character.RESOURCE_STATS) do RESOURCE[key] = true end

-- The ten numbers. Resource stats are { max, current } pools at runtime, so the setter moves `max`
-- and drags `current` with it -- editing a blueprint's HP and watching the bar stay at the old value
-- would read as the edit not having taken.
local STAT_FIELDS = {}
for _, key in ipairs(STAT_KEYS) do
    STAT_FIELDS[#STAT_FIELDS + 1] = {
        key = key,
        label = STAT_LABEL[key],
        kind = "number",
        get = function(char)
            local live = char.stats and char.stats[key]
            if live == nil then return 0 end
            return RESOURCE[key] and live.max or live
        end,
        set = function(char, v)
            char.stats = char.stats or {}
            if RESOURCE[key] then
                char.stats[key] = char.stats[key] or { max = v, current = v }
                char.stats[key].max = v
                char.stats[key].current = v
            else
                char.stats[key] = v
            end
        end,
    }
end

local IDENTITY_FIELDS = {
    {
        key = "name", label = "Name", kind = "text",
        get = function(char) return char.name or "?" end,
    },
    {
        key = "class", label = "Growth Class", kind = "cycle",
        options = function()
            local out = { false } -- class-less is real: the avatar ships without one
            for _, c in ipairs(sortedKeys(Item.CLASSES)) do out[#out + 1] = c end
            return out
        end,
        get = function(char) return char.class or false end,
        set = function(char, v) char.class = v or nil end,
    },
    {
        key = "boss", label = "Boss", kind = "cycle",
        options = function() return { false, true } end,
        get = function(char) return char.boss or false end,
        set = function(char, v) char.boss = v or nil end,
    },
    {
        key = "unarmed", label = "Natural Weapon", kind = "cycle",
        options = unarmedOptions,
        get = function(char) return char.unarmed and char.unarmed.id or false end,
        -- Held as a live instance, exactly as Character.instantiate builds it, so the character can be
        -- dropped into a battle straight from the editor and actually swing it.
        set = function(char, v) char.unarmed = v and Item.instantiate(v) or nil end,
    },
    {
        key = "spritePath", label = "Sprite", kind = "path", dir = "assets/chars",
        get = function(char) return char.spritePath or false end,
    },
    {
        key = "portraitPath", label = "Portrait", kind = "path", dir = "assets/portraits",
        get = function(char) return char.portraitPath or false end,
    },
}

StatEditor.STAT_FIELDS = STAT_FIELDS
StatEditor.IDENTITY_FIELDS = IDENTITY_FIELDS

-- Step `value` through `options` by `dir`, wrapping. Mirrors TacticsEditor.cycle; `false` is a real
-- option here rather than an absence, so identity compares directly.
function StatEditor.cycle(options, value, dir)
    if #options == 0 then return value end
    local index = 1
    for i, opt in ipairs(options) do
        if opt == value then index = i break end
    end
    return options[(index - 1 + dir) % #options + 1]
end

-- How a value prints. `false` is the one that needs saying out loud -- an empty cell would read as a
-- rendering bug rather than a deliberate "none".
local function valueLabel(field, value)
    if value == false or value == nil then
        return field.kind == "path" and "(none)" or "none"
    end
    if value == true then return "yes" end
    -- A path shows its filename; the directory is fixed per field and printing it would cost the row
    -- its whole width to say nothing.
    if field.kind == "path" then return (tostring(value):match("([^/]+)$")) end
    -- An item shows its NAME, not its id: "Fists" is what the rest of the game calls the thing, and
    -- the id is recoverable from the field's own list.
    if field.key == "unarmed" then
        local def = Item.defs[value]
        return def and def.name or tostring(value)
    end
    return tostring(value)
end

-- Trim `text` with an ellipsis until it fits `w`. A long name has to lose its tail rather than run
-- under the arrow that changes it.
local function fit(font, text, w)
    if font:getWidth(text) <= w then return text end
    while #text > 1 and font:getWidth(text .. "...") > w do
        text = text:sub(1, #text - 1)
    end
    return text .. "..."
end

function StatEditor.new(opts)
    local self = setmetatable({}, StatEditor)
    self.x, self.y, self.w, self.h = opts.x, opts.y, opts.w, opts.h
    self.fonts = opts.fonts
    -- Renaming needs a text field, and this widget has no room for one; the host owns the swap to
    -- ui/name_entry.lua and hands the result back.
    self.onEditName = opts.onEditName

    self.region = "stats"
    self.statCursor = 1
    self.identityCursor = 1
    self.hoverRow, self.hoverArrow = nil, nil
    self.statRects, self.identityRects = {}, {}

    -- Split: the numbers on the left, identity on the right -- the same 56/44 proportion the rule
    -- editor uses, so the two tabs sit on one grid rather than two.
    self.listW = math.floor(self.w * 0.56)
    self.editX = self.x + self.listW + 20
    self.editW = self.w - self.listW - 20

    self:setChar(opts.char)
    return self
end

function StatEditor:setChar(char)
    self.char = char
    self.statCursor = 1
    self.identityCursor = 1
end

-- The field list for a region, and the cursor into it. One accessor, so navigation, drawing and
-- mouse hit-testing cannot disagree about which list is on screen.
function StatEditor:fields(region)
    region = region or self.region
    if region == "identity" then return IDENTITY_FIELDS, self.identityCursor end
    return STAT_FIELDS, self.statCursor
end

function StatEditor:setCursor(region, i)
    local fields = self:fields(region)
    i = math.max(1, math.min(#fields, i))
    if region == "identity" then self.identityCursor = i else self.statCursor = i end
end

-- ---------------------------------------------------------------------------
-- Column-editor contract (see Party:columnEditor)
-- ---------------------------------------------------------------------------

function StatEditor:isFirstRegion() return self.region == "stats" end
function StatEditor:resetRegion() self.region = "stats" end

function StatEditor:cycleRegion()
    self.region = (self.region == "stats") and "identity" or "stats"
end

function StatEditor:navigate(dc, dr)
    local fields, cursor = self:fields()
    if dr ~= 0 then
        self:setCursor(self.region, cursor + dr)
        return
    end
    if dc ~= 0 then
        self:adjust(fields[cursor], dc)
    end
end

-- Change one field by one step. `shift` multiplies a numeric step by ten, which is the difference
-- between tuning a stat and giving up on the keyboard.
function StatEditor:adjust(field, dir)
    local char = self.char
    if not (char and field) then return end

    if field.kind == "number" then
        local step = 1
        if love and love.keyboard and love.keyboard.isDown
            and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
            step = 10
        end
        local value = field.get(char) + dir * step
        field.set(char, math.max(STAT_MIN, math.min(STAT_MAX, value)))
    elseif field.kind == "cycle" then
        field.set(char, StatEditor.cycle(field.options(), field.get(char), dir))
    elseif field.kind == "path" then
        local options = assetPaths(field.dir)
        local value = StatEditor.cycle(options, field.get(char), dir)
        char[field.key] = value or nil
        -- The runtime `sprite`/`portrait` are loaded images; re-load them so the rail portrait and the
        -- focus sheet show the newly chosen art immediately rather than at next instantiate.
        local Sprite = require("models.sprite")
        if field.key == "spritePath" then char.sprite = Sprite.load(value or nil)
        else char.portrait = Sprite.load(value or nil) end
    end
end

function StatEditor:confirm()
    local fields, cursor = self:fields()
    local field = fields[cursor]
    if not field then return end
    if field.kind == "text" then
        if self.onEditName then self.onEditName(self.char) end
    else
        self:adjust(field, 1)
    end
end

-- Nothing here is modal, so there is never a pickup to drop: cancel is always "I did not catch that",
-- which lets the panel fall through to closing.
function StatEditor:cancel()
    return false
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function StatEditor:draw()
    local f = self.fonts
    if not self.char then return end

    love.graphics.setFont(f.small)
    setColor(C_DIM)
    love.graphics.print("Stats", self.x, self.y)
    love.graphics.print("Identity", self.editX, self.y)

    self.statRects = self:drawColumn(STAT_FIELDS, "stats", self.x, self.listW, self.statCursor)
    self.identityRects = self:drawColumn(IDENTITY_FIELDS, "identity", self.editX, self.editW, self.identityCursor)

    -- The blueprint this would be written as, named in full, so the destination of an S press is
    -- never a guess.
    love.graphics.setFont(f.tiny)
    setColor(C_TEXT_OFF)
    love.graphics.printf("Writes to data/characters/" .. tostring(self.char.id) .. ".lua",
        self.x, self.y + self.h - 16, self.w, "left")

    love.graphics.setColor(1, 1, 1)
end

function StatEditor:drawColumn(fields, region, x, w, cursor)
    local f = self.fonts
    local rects = {}
    local y = self.y + 24

    for i, field in ipairs(fields) do
        local selected = (self.region == region and cursor == i)
        local r = { x = x, y = y, w = w, h = ROW_H }
        rects[i] = r

        setColor(selected and C_ROW_SEL or C_ROW)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
        if selected then
            setColor(C_ACCENT, 0.7)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
        end

        love.graphics.setFont(f.tiny)
        setColor(C_DIM)
        love.graphics.print(field.label, r.x + 8, r.y + (ROW_H - f.tiny:getHeight()) / 2)

        -- "< value >" occupies a fixed zone at the row's right edge: arrows pinned to its ends, the
        -- value centred between them.
        local zoneX = r.x + r.w - VALUE_W - 6
        local ty = r.y + (ROW_H - f.small:getHeight()) / 2
        local value = field.get(self.char)
        love.graphics.setFont(f.small)

        if field.kind ~= "text" then
            -- No arrows on a name: it is typed, not cycled, and drawing them would promise otherwise.
            local hovered = self.hoverRow == region .. i
            setColor((hovered and self.hoverArrow == "-") and C_ACCENT or C_DIM)
            love.graphics.printf("<", zoneX, ty, ARROW_W, "center")
            setColor((hovered and self.hoverArrow == "+") and C_ACCENT or C_DIM)
            love.graphics.printf(">", zoneX + VALUE_W - ARROW_W, ty, ARROW_W, "center")
        end

        local innerW = VALUE_W - ARROW_W * 2 - 8
        setColor((value == false or value == nil) and C_TEXT_OFF or C_TEXT)
        love.graphics.printf(fit(f.small, valueLabel(field, value), innerW),
            zoneX + ARROW_W + 4, ty, innerW, "center")

        y = y + ROW_H + ROW_GAP
    end
    return rects
end

-- ---------------------------------------------------------------------------
-- Mouse
-- ---------------------------------------------------------------------------

function StatEditor:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

-- The row under the pointer, as region + index + which half of the value area it is on.
function StatEditor:rowAt(x, y)
    for _, spec in ipairs({ { "stats", self.statRects }, { "identity", self.identityRects } }) do
        for i, r in ipairs(spec[2]) do
            if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
                -- Split at the middle of the value zone, so each half of "< value >" steps the way
                -- the arrow on that side points.
                local mid = r.x + r.w - 6 - VALUE_W / 2
                return spec[1], i, (x < mid) and "-" or "+"
            end
        end
    end
    return nil
end

function StatEditor:mousemoved(x, y)
    local region, i, arrow = self:rowAt(x, y)
    self.hoverRow = region and (region .. i) or nil
    self.hoverArrow = arrow
end

function StatEditor:mousepressed(x, y)
    local region, i, arrow = self:rowAt(x, y)
    if not region then return false end
    self.region = region
    self:setCursor(region, i)
    local fields = self:fields(region)
    local field = fields[i]
    if field.kind == "text" then
        if self.onEditName then self.onEditName(self.char) end
    else
        self:adjust(field, arrow == "-" and -1 or 1)
    end
    return true
end

function StatEditor:wheelmoved(dy)
    if dy == 0 then return end
    local fields, cursor = self:fields()
    self:setCursor(self.region, cursor - dy)
    local _ = fields
end

function StatEditor:cursorKind(x, y)
    return self:rowAt(x, y) and "hand" or "arrow"
end

function StatEditor:prompts()
    local pad = InputMode.isGamepad()
    local fields, cursor = self:fields()
    local field = fields[cursor]
    local segments = {
        { glyph = pad and "D-Pad" or "Arrows", label = field and field.kind == "number"
            and "Adjust (Shift x10)" or "Change" },
        { glyph = pad and "Y" or "Tab", label = "Stats/Identity" },
    }
    if field and field.kind == "text" then
        segments[#segments + 1] = { glyph = pad and "A" or "Enter", label = "Rename",
            color = { 0.55, 0.90, 0.58 } }
    end
    return segments
end

return StatEditor
