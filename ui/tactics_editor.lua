-- Tactics rule editor: the ordered gambit list for one character, plus a field editor for the
-- selected rule. Lives on the Loadout panel's second tab (ui/panels/party.lua).
--
-- It edits `char.aiRules` -- the PLAYER source that models/ai.lua merges above the item-borne and
-- posture-default rules. It never shows or edits those other sources: they are content, not settings,
-- and a list mixing "rules you wrote" with "rules your sword came with" would make the delete key a
-- lie. What it does show is the archetype (which posture backs the list) and the auto-battle switch
-- (whether the list ever runs at all), because a rule list with neither of those visible is a form
-- with no submit button.
--
-- Two regions, crossed with Tab / Y:
--
--   rules   -- the ordered rows: enable box, priority band, the rule as a sentence
--   fields  -- the selected rule's fields, one per line, cycled with left/right
--
-- Reordering reuses the Loadout screen's pick-then-place idiom rather than inventing a second one:
-- confirm GRABS a row, up/down carries it, confirm drops it. Priority governs the merge against the
-- other sources; position within this list is what breaks ties inside it, so both are editable and
-- they mean different things.
--
--   local ed = TacticsEditor.new({ x, y, w, h, char = char, fonts = { ... } })

local AI = require("models.ai")
local Status = require("models.status")
local InputMode = require("input_mode")

local TacticsEditor = {}
TacticsEditor.__index = TacticsEditor

-- Tall enough for the two stacked lines a row carries (the priority band, then the rule as a
-- sentence) with the sentence's descenders clear of the row edge.
local ROW_H = 42
local ROW_GAP = 5
local DELETE_W = 26 -- reserved on the right, so a long rule wraps short of the x rather than under it
local BOX = 16          -- the enable checkbox
local FIELD_H = 28
local ARROW_W = 18

-- Row tints. A disabled rule is drawn dim rather than hidden, so the list keeps its shape while the
-- player toggles rows to work out which one is misbehaving.
local C_ROW      = { 0.17, 0.18, 0.24 }
local C_ROW_SEL  = { 0.24, 0.27, 0.36 }
local C_ROW_GRAB = { 0.32, 0.30, 0.18 }
local C_TEXT     = { 0.86, 0.88, 0.94 }
local C_TEXT_OFF = { 0.46, 0.48, 0.54 }
local C_ACCENT   = { 0.98, 0.82, 0.30 }
local C_DIM      = { 0.62, 0.65, 0.74 }

-- Priority band tints, warm (act now) to cool (act eventually), so the list's shape is readable
-- before a single word of it is.
local C_BAND = {
    emergency = { 0.95, 0.45, 0.42 },
    urgent    = { 0.95, 0.65, 0.38 },
    high      = { 0.92, 0.85, 0.45 },
    normal    = { 0.62, 0.78, 0.62 },
    low       = { 0.52, 0.68, 0.85 },
    fallback  = { 0.58, 0.58, 0.68 },
}

-- ---------------------------------------------------------------------------
-- Field descriptors
-- ---------------------------------------------------------------------------
--
-- Every field is "read a value off the rule, cycle it through an ordered list, write it back". Held
-- as data so the draw loop, the input loop and the tests all walk the same definition instead of
-- three hand-kept copies of it.
--
-- `when` is nil on a field that is always shown; otherwise it decides visibility from the rule (the
-- value field is absent for a test that takes no value, and target preference is meaningless for a
-- rule that does not aim at anybody).
--
-- Every function takes (rule, char). Most ignore the character, but the Item field cannot: its
-- options ARE that character's kit, which is why the parameter is on all of them rather than on the
-- one that needs it -- a signature that varies per field is a signature nobody can call generically.

local function statusIds()
    local out = {}
    for id in pairs(Status.defs) do out[#out + 1] = id end
    table.sort(out) -- pairs has no order; the list must not shuffle between runs
    return out
end

local FIELDS = {
    {
        key = "priority", label = "Priority",
        options = function() return AI.PRIORITY_ORDER end,
        get = function(rule) return rule.priority or "normal" end,
        set = function(rule, v) rule.priority = v end,
    },
    {
        key = "act", label = "Action",
        options = function() return AI.ACTION_ORDER end,
        get = function(rule) return rule.act or "attack" end,
        set = function(rule, v) rule.act = v end,
    },
    {
        key = "subject", label = "Subject",
        options = function() return AI.SUBJECT_ORDER end,
        get = function(rule) return rule.when and rule.when.subject or "nearest_foe" end,
        set = function(rule, v)
            rule.when = rule.when or {}
            rule.when.subject = v
        end,
    },
    {
        key = "test", label = "Condition",
        options = function() return AI.TEST_ORDER end,
        get = function(rule) return rule.when and rule.when.test or "exists" end,
        set = function(rule, v)
            rule.when = rule.when or {}
            rule.when.test = v
            -- Changing the test changes what a value MEANS -- 0.5 as a health fraction is nonsense as
            -- a tile count. Reset to the new test's own default rather than carrying the old number
            -- across, and drop it entirely for a test that takes none.
            local spec = AI.TEST_VALUE[v]
            rule.when.value = spec and spec.default or nil
        end,
    },
    {
        key = "value", label = "Value",
        when = function(rule)
            return AI.TEST_VALUE[rule.when and rule.when.test or ""] ~= nil
        end,
        options = function(rule)
            local spec = AI.TEST_VALUE[rule.when.test]
            if spec.kind == "status" then return statusIds() end
            local out = {}
            for v = spec.min, spec.max + 1e-9, spec.step do out[#out + 1] = v end
            return out
        end,
        get = function(rule)
            local spec = AI.TEST_VALUE[rule.when.test]
            return rule.when.value ~= nil and rule.when.value or (spec and spec.default)
        end,
        set = function(rule, v) rule.when.value = v end,
        display = function(rule, v) return AI.describeValue(rule.when.test, v) end,
    },
    {
        -- Which item to use, or "any" to let the scorer choose from the whole kit. Stored as an id
        -- string rather than a grid slot (see AI.resolveItem): the player means "cast Heal", and this
        -- screen's other tab exists to rearrange the grid, so a slot would silently repoint the rule.
        key = "item", label = "Using",
        when = function(rule)
            local act = rule.act or "attack"
            return act == "attack" or act == "support" or act == "cast"
        end,
        options = function(_, char)
            local out = { false } -- "any" is a real choice and has to be reachable again
            if char then
                for _, item in ipairs(require("models.combat").abilityItems(char)) do
                    out[#out + 1] = item.id
                end
                if char.unarmed then out[#out + 1] = char.unarmed.id end
            end
            return out
        end,
        get = function(rule) return rule.item or false end,
        set = function(rule, v) rule.item = v or nil end,
        display = function(rule, v)
            if not v then return "any" end
            local name = AI.itemName(v)
            -- Say so when the rule names something no longer in the grid, rather than showing a name
            -- that implies it will fire. A stowed or sold item leaves the rule dormant, and the
            -- player has to be able to see that from the row.
            return name
        end,
    },
    {
        key = "targetPref", label = "Prefer",
        when = function(rule)
            local act = rule.act or "attack"
            return act == "attack" or act == "support" or act == "cast"
        end,
        options = function() return AI.TARGET_PREF_ORDER end,
        get = function(rule) return rule.targetPref or "nearest" end,
        set = function(rule, v) rule.targetPref = v end,
    },
}

TacticsEditor.FIELDS = FIELDS

-- The fields visible for `rule`, in order. Pure and static, so the tests can walk the same list the
-- draw loop does without standing up a panel.
function TacticsEditor.visibleFields(rule, char)
    local out = {}
    if not rule then return out end
    for _, f in ipairs(FIELDS) do
        if not f.when or f.when(rule, char) then out[#out + 1] = f end
    end
    return out
end

-- Step `value` through `options` by `dir`, wrapping. Numbers compare by proximity rather than
-- identity: a value authored as 0.5 must find itself in a list built by repeated addition, where the
-- matching entry may be 0.5000000001.
function TacticsEditor.cycle(options, value, dir)
    if #options == 0 then return value end
    local index = 1
    for i, opt in ipairs(options) do
        if opt == value
            or (type(opt) == "number" and type(value) == "number" and math.abs(opt - value) < 1e-6) then
            index = i
            break
        end
    end
    return options[(index - 1 + dir) % #options + 1]
end

-- Move the rule at `from` to `to`, clamped, returning the index it ended up at. Pure, so reordering
-- is testable at its boundaries without a panel or a mouse.
function TacticsEditor.moveRule(rules, from, to)
    if not rules[from] then return from end
    to = math.max(1, math.min(#rules, to))
    if to == from then return from end
    local rule = table.remove(rules, from)
    table.insert(rules, to, rule)
    return to
end

-- Pretty-print an option for display: a field's own formatter if it has one, else the raw name with
-- underscores opened out.
local function optionLabel(field, rule, value, char)
    if field.display then return field.display(rule, value, char) or "-" end
    return tostring(value):gsub("_", " ")
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

function TacticsEditor.new(opts)
    local self = setmetatable({}, TacticsEditor)
    self.x, self.y, self.w, self.h = opts.x, opts.y, opts.w, opts.h
    self.fonts = opts.fonts
    self.region = "rules"
    self.cursor = 1        -- row index; #rules + 1 is the "+ Add rule" row
    self.fieldCursor = 1
    self.grabbed = nil     -- index of the row being carried, or nil
    self.scroll = 0
    self.hoverRow, self.hoverField, self.hoverArrow = nil, nil, nil
    self.rowRects, self.fieldRects = {}, {}

    -- Split: rule list on the left, field editor on the right.
    self.listW = math.floor(self.w * 0.56)
    self.editX = self.x + self.listW + 20
    self.editW = self.w - self.listW - 20
    -- The archetype + auto-battle strip sits along the bottom of the list column.
    self.footY = self.y + self.h - 64

    self:setChar(opts.char)
    return self
end

function TacticsEditor:setChar(char)
    self.char = char
    -- The list is created on demand rather than at instantiate: a character who never opens this tab
    -- should not gain an empty `aiRules` table that then has to be persisted and reasoned about.
    self.cursor = 1
    self.fieldCursor = 1
    self.grabbed = nil
    self.scroll = 0
end

function TacticsEditor:rules()
    local char = self.char
    if not char then return {} end
    char.aiRules = char.aiRules or {}
    return char.aiRules
end

function TacticsEditor:selectedRule()
    return self:rules()[self.cursor]
end

function TacticsEditor:visibleRows()
    return math.max(1, math.floor((self.footY - self.y - 24) / (ROW_H + ROW_GAP)))
end

-- ---------------------------------------------------------------------------
-- Mutation
-- ---------------------------------------------------------------------------

function TacticsEditor:addRule()
    local rules = self:rules()
    rules[#rules + 1] = AI.newRule()
    self.cursor = #rules
    self.fieldCursor = 1
    return rules[#rules]
end

function TacticsEditor:removeRule(index)
    local rules = self:rules()
    if not rules[index] then return false end
    table.remove(rules, index)
    self.cursor = math.max(1, math.min(#rules + 1, index))
    self.grabbed = nil
    return true
end

function TacticsEditor:toggleEnabled(index)
    local rule = self:rules()[index]
    if not rule then return false end
    rule.enabled = rule.enabled == false
    return true
end

function TacticsEditor:cycleArchetype(dir)
    local char = self.char
    if not char then return end
    -- nil ("Default") is a real, reachable option, not an absence -- a player who tried an archetype
    -- and wants out again has to be able to get back to it.
    local names = { false }
    for name in pairs(AI.POSTURES) do names[#names + 1] = name end
    table.sort(names, function(a, b) return tostring(a) < tostring(b) end)
    local current = char.archetype or false
    char.archetype = TacticsEditor.cycle(names, current, dir) or nil
end

function TacticsEditor:toggleAuto()
    local char = self.char
    if not char then return end
    char.autoBattle = not char.autoBattle
end

-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------

function TacticsEditor:rowCount()
    return #self:rules() + 1 -- the trailing "+ Add rule" row
end

function TacticsEditor:navigate(dc, dr)
    if self.region == "rules" then
        if dr ~= 0 then
            if self.grabbed then
                -- Carrying a row: up/down moves the ROW, not the cursor. The two must not both
                -- happen, or the grabbed rule slides out from under the selection.
                local to = math.max(1, math.min(#self:rules(), self.grabbed + dr))
                self.grabbed = TacticsEditor.moveRule(self:rules(), self.grabbed, to)
                self.cursor = self.grabbed
            else
                self.cursor = math.max(1, math.min(self:rowCount(), self.cursor + dr))
            end
            self:scrollToCursor()
        end
    else
        local fields = TacticsEditor.visibleFields(self:selectedRule(), self.char)
        if dr ~= 0 and #fields > 0 then
            self.fieldCursor = math.max(1, math.min(#fields, self.fieldCursor + dr))
        end
        if dc ~= 0 then self:cycleField(dc) end
    end
end

function TacticsEditor:scrollToCursor()
    local visible = self:visibleRows()
    if self.cursor - 1 < self.scroll then
        self.scroll = self.cursor - 1
    elseif self.cursor > self.scroll + visible then
        self.scroll = self.cursor - visible
    end
    self.scroll = math.max(0, self.scroll)
end

function TacticsEditor:cycleField(dir)
    local rule = self:selectedRule()
    if not rule then return end
    local fields = TacticsEditor.visibleFields(rule, self.char)
    local field = fields[self.fieldCursor]
    if not field then return end
    field.set(rule, TacticsEditor.cycle(field.options(rule, self.char), field.get(rule, self.char), dir),
        self.char)
end

-- Confirm on the focused region. On a rule row this grabs/drops it (reorder); on the add row it adds.
function TacticsEditor:confirm()
    if self.region == "fields" then
        self:cycleField(1)
        return
    end
    local rules = self:rules()
    if self.cursor > #rules then
        self:addRule()
        return
    end
    self.grabbed = (self.grabbed == self.cursor) and nil or self.cursor
end

function TacticsEditor:cancel()
    -- Report whether there was something to cancel, so the panel knows whether Esc should also close
    -- it (the same contract InventoryGrid:cancelPickup keeps).
    if self.grabbed then self.grabbed = nil return true end
    if self.region == "fields" then self.region = "rules" return true end
    return false
end

function TacticsEditor:cycleRegion()
    self.region = (self.region == "rules") and "fields" or "rules"
    if self.region == "fields" and not self:selectedRule() then self.region = "rules" end
end

-- Column-editor contract (see Party:columnEditor). The host walks Tab through the editor's own
-- regions before handing focus back out, and needs to ask where the walk starts and ends without
-- knowing what this particular editor calls its regions.
function TacticsEditor:isFirstRegion()
    return self.region == "rules"
end

function TacticsEditor:resetRegion()
    self.region = "rules"
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

local function setColor(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

function TacticsEditor:rowRect(i)
    local slot = i - self.scroll
    if slot < 1 or slot > self:visibleRows() then return nil end
    return { x = self.x, y = self.y + 24 + (slot - 1) * (ROW_H + ROW_GAP), w = self.listW, h = ROW_H }
end

function TacticsEditor:draw()
    local f = self.fonts
    local rules = self:rules()

    love.graphics.setFont(f.small)
    setColor(C_DIM)
    love.graphics.print("Rules (" .. #rules .. ") -- first match wins", self.x, self.y)

    self.rowRects = {}
    for i = 1, self:rowCount() do
        local r = self:rowRect(i)
        if r then
            self.rowRects[i] = r
            if i > #rules then self:drawAddRow(r, i) else self:drawRuleRow(r, i, rules[i]) end
        end
    end

    self:drawFooter()
    self:drawFields()
    love.graphics.setColor(1, 1, 1)
end

function TacticsEditor:drawRuleRow(r, i, rule)
    local f = self.fonts
    local selected = (self.region == "rules" and self.cursor == i)
    local on = rule.enabled ~= false

    setColor(self.grabbed == i and C_ROW_GRAB or (selected and C_ROW_SEL or C_ROW))
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    if selected then
        setColor(C_ACCENT, self.grabbed == i and 1 or 0.7)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    end

    -- Enable checkbox.
    local bx, by = r.x + 8, r.y + (r.h - BOX) / 2
    setColor(on and C_ACCENT or C_TEXT_OFF)
    love.graphics.rectangle("line", bx, by, BOX, BOX, 3, 3)
    if on then love.graphics.rectangle("fill", bx + 4, by + 4, BOX - 8, BOX - 8, 2, 2) end

    -- Priority band pip + name: the list's shape should read before any of its words do.
    local band = AI.priorityName(rule)
    local px = bx + BOX + 10
    setColor(C_BAND[band] or C_DIM, on and 1 or 0.4)
    love.graphics.rectangle("fill", px, r.y + 6, 4, r.h - 12, 2, 2)

    love.graphics.setFont(f.tiny)
    love.graphics.print(band, px + 10, r.y + 5)

    -- The rule as a sentence, minus the band (already shown as the pip). Width-clamped short of the
    -- delete button and clipped to one line: a rule long enough to wrap would otherwise grow the row
    -- out of its own rectangle.
    local textX = px + 10
    local textW = (r.x + r.w - DELETE_W) - textX
    love.graphics.setFont(f.small)

    -- A rule naming an item the character isn't carrying can never fire. Flagged on the ROW, not
    -- only in the field editor: the player has to be able to see which of ten rules is dead without
    -- selecting each one in turn.
    local dormant = rule.item and not AI.resolveItem(self.char or {}, rule.item)
    setColor(dormant and { 0.95, 0.55, 0.5 } or (on and C_TEXT or C_TEXT_OFF))
    local text = AI.describeRule(rule):gsub("^[%a]+: ", "")
    if dormant then text = text .. "  -- not carried" end
    while text ~= "" and f.small:getWidth(text) > textW do
        text = text:sub(1, -2)
    end
    love.graphics.print(text, textX, r.y + 3 + f.tiny:getHeight())

    -- Delete affordance, mouse-reachable (the keyboard/pad path is the Delete/X binding).
    local dx = r.x + r.w - 20
    setColor(self.hoverDelete == i and { 0.95, 0.5, 0.47 } or C_TEXT_OFF)
    love.graphics.setFont(f.small)
    love.graphics.print("x", dx, r.y + (r.h - f.small:getHeight()) / 2)
end

function TacticsEditor:drawAddRow(r, i)
    local selected = (self.region == "rules" and self.cursor == i)
    setColor(selected and C_ROW_SEL or C_ROW, 0.6)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    setColor(selected and C_ACCENT or C_TEXT_OFF, selected and 0.7 or 0.5)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setFont(self.fonts.small)
    setColor(selected and C_ACCENT or C_DIM)
    love.graphics.printf("+ Add rule", r.x, r.y + (r.h - self.fonts.small:getHeight()) / 2, r.w, "center")
end

-- Archetype + auto-battle. These frame the whole list: the archetype is what backs it when no rule
-- matches, and auto-battle is whether any of it runs at all.
function TacticsEditor:drawFooter()
    local f = self.fonts
    local char = self.char
    if not char then return end

    love.graphics.setFont(f.tiny)
    setColor(C_DIM)
    love.graphics.print("Archetype", self.x, self.footY)
    love.graphics.print("Auto-battle", self.x + 200, self.footY)

    love.graphics.setFont(f.small)
    setColor(C_TEXT)
    local name = (char.archetype or "default"):gsub("_", " ")
    self.archRect = { x = self.x, y = self.footY + 14, w = 180, h = 24 }
    setColor(C_ROW)
    love.graphics.rectangle("fill", self.archRect.x, self.archRect.y, self.archRect.w, self.archRect.h, 4, 4)
    setColor(C_TEXT)
    love.graphics.printf("< " .. name .. " >", self.archRect.x, self.archRect.y + 4, self.archRect.w, "center")

    self.autoRect = { x = self.x + 200, y = self.footY + 14, w = 90, h = 24 }
    setColor(char.autoBattle and { 0.35, 0.55, 0.38 } or C_ROW)
    love.graphics.rectangle("fill", self.autoRect.x, self.autoRect.y, self.autoRect.w, self.autoRect.h, 4, 4)
    setColor(char.autoBattle and { 0.75, 0.95, 0.75 } or C_TEXT_OFF)
    love.graphics.printf(char.autoBattle and "ON" or "OFF",
        self.autoRect.x, self.autoRect.y + 4, self.autoRect.w, "center")

    -- Say what the switch actually does, once, where it is -- rather than nowhere.
    love.graphics.setFont(f.tiny)
    setColor(C_DIM)
    love.graphics.printf(char.autoBattle
        and "Acts on its own turn. Press any key to take over."
        or "You control this unit in battle.",
        self.x + 300, self.footY + 18, self.w - 300, "left")
end

function TacticsEditor:drawFields()
    local f = self.fonts
    local rule = self:selectedRule()

    love.graphics.setFont(f.small)
    setColor(C_DIM)
    love.graphics.print("Selected rule", self.editX, self.y)

    self.fieldRects = {}
    if not rule then
        love.graphics.setFont(f.tiny)
        setColor(C_TEXT_OFF)
        love.graphics.printf(
            "No rule selected.\n\nAdd one to tell this character what to do when it is running itself."
            .. "\n\nRules are checked top to bottom; the first one that matches and can be carried out"
            .. " takes the turn.",
            self.editX, self.y + 28, self.editW, "left")
        return
    end

    local fields = TacticsEditor.visibleFields(rule, self.char)
    local y = self.y + 26
    for i, field in ipairs(fields) do
        local selected = (self.region == "fields" and self.fieldCursor == i)
        local r = { x = self.editX, y = y, w = self.editW, h = FIELD_H }
        self.fieldRects[i] = r

        love.graphics.setFont(f.tiny)
        setColor(C_DIM)
        love.graphics.print(field.label, r.x, r.y)

        local vy = r.y + 13
        setColor(selected and C_ROW_SEL or C_ROW)
        love.graphics.rectangle("fill", r.x, vy, r.w, 24, 4, 4)
        if selected then
            setColor(C_ACCENT, 0.7)
            love.graphics.rectangle("line", r.x, vy, r.w, 24, 4, 4)
        end

        love.graphics.setFont(f.small)
        setColor(self.hoverArrow == i .. "-" and C_ACCENT or C_DIM)
        love.graphics.printf("<", r.x + 4, vy + 4, ARROW_W, "center")
        setColor(self.hoverArrow == i .. "+" and C_ACCENT or C_DIM)
        love.graphics.printf(">", r.x + r.w - ARROW_W - 4, vy + 4, ARROW_W, "center")

        -- A rule pinned to an item the character is no longer carrying is dormant, and the field says
        -- so in place rather than showing a name that implies it will fire.
        local value = field.get(rule, self.char)
        local dormant = field.key == "item" and value
            and not AI.resolveItem(self.char or {}, value)
        setColor(dormant and { 0.95, 0.55, 0.5 } or C_TEXT)
        local label = optionLabel(field, rule, value, self.char)
        if dormant then label = label .. " (not carried)" end
        love.graphics.printf(label, r.x + ARROW_W + 6, vy + 4, r.w - (ARROW_W + 6) * 2, "center")

        y = y + FIELD_H + 12
    end

    -- The finished sentence, so the player can read what they built without decoding six fields.
    love.graphics.setFont(f.tiny)
    setColor(C_DIM)
    love.graphics.printf(AI.describeRule(rule), self.editX, y + 6, self.editW, "left")
end

-- ---------------------------------------------------------------------------
-- Mouse
-- ---------------------------------------------------------------------------

function TacticsEditor:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function TacticsEditor:mousemoved(x, y)
    self.hoverRow, self.hoverDelete, self.hoverField, self.hoverArrow = nil, nil, nil, nil
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) then
            self.hoverRow = i
            if x >= r.x + r.w - DELETE_W then self.hoverDelete = i end
        end
    end
    for i, r in pairs(self.fieldRects) do
        if hit({ x = r.x, y = r.y + 13, w = r.w, h = 24 }, x, y) then
            self.hoverField = i
            if x <= r.x + ARROW_W + 4 then self.hoverArrow = i .. "-"
            elseif x >= r.x + r.w - ARROW_W - 4 then self.hoverArrow = i .. "+" end
        end
    end
end

-- Returns true when the click was consumed, so the panel knows not to treat it as a click-outside.
function TacticsEditor:mousepressed(x, y)
    if hit(self.archRect, x, y) then
        -- Left half steps back, right half forward -- the "< name >" affordance means what it looks
        -- like rather than only cycling one way.
        self:cycleArchetype(x < self.archRect.x + self.archRect.w / 2 and -1 or 1)
        return true
    end
    if hit(self.autoRect, x, y) then self:toggleAuto() return true end

    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) then
            self.region = "rules"
            local rules = self:rules()
            if i > #rules then
                self:addRule()
            elseif x >= r.x + r.w - DELETE_W then
                self:removeRule(i)
            elseif x <= r.x + 8 + BOX + 4 then
                self.cursor = i
                self:toggleEnabled(i)
            else
                self.cursor = i
                self.fieldCursor = 1
            end
            return true
        end
    end

    for i, r in pairs(self.fieldRects) do
        if hit({ x = r.x, y = r.y + 13, w = r.w, h = 24 }, x, y) then
            self.region = "fields"
            self.fieldCursor = i
            if x <= r.x + ARROW_W + 4 then self:cycleField(-1)
            elseif x >= r.x + r.w - ARROW_W - 4 then self:cycleField(1) end
            return true
        end
    end
    return false
end

function TacticsEditor:wheelmoved(dy)
    local maxScroll = math.max(0, self:rowCount() - self:visibleRows())
    self.scroll = math.max(0, math.min(maxScroll, self.scroll - dy))
end

function TacticsEditor:cursorKind(x, y)
    if hit(self.archRect, x, y) or hit(self.autoRect, x, y) then return "hand" end
    if self.hoverRow or self.hoverField then return "hand" end
    return "arrow"
end

-- Contextual prompt segments for the panel's footer bar, so the controls are spelt out for whichever
-- device is in hand rather than left to be discovered.
function TacticsEditor:prompts()
    local pad = InputMode.isGamepad()
    local out = {}
    local function add(glyph, label, color) out[#out + 1] = { glyph = glyph, label = label, color = color } end
    if self.region == "fields" then
        add(pad and "D-pad" or "Arrows", "Change")
        add(pad and "Y" or "Tab", "Back to rules")
    elseif self.grabbed then
        add(pad and "D-pad" or "Arrows", "Move rule")
        add(pad and "A" or "Enter", "Drop")
    else
        add(pad and "A" or "Enter", (self.cursor > #self:rules()) and "Add rule" or "Grab")
        add(pad and "Y" or "Tab", "Edit fields")
        add(pad and "X" or "F", "Enable")
        add(pad and "Back" or "Del", "Delete")
    end
    return out
end

return TacticsEditor
