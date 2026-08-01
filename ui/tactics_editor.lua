-- Tactics rule editor: the ordered gambit list for one character, plus a field editor for the
-- selected rule. Lives on the Loadout panel's second tab (ui/panels/party.lua).
--
-- It edits the character's OWN rules -- the one channel that is theirs, as opposed to the rules their
-- weapon came with (an item's `ai`) or the posture floor everyone stands on. That channel is stored
-- two ways, and `opts.ownKey` chooses which end this instance owns:
--
--   "aiRules" (default, in-game)   the player's overlay. The character starts on its blueprint's own
--                                  list (`char.ai`), which is shown here as inherited rows; the first
--                                  edit SEEDS `char.aiRules` from that list (so nothing is lost) and
--                                  from then on every change persists to the save. See models/ai.lua
--                                  for why the overlay replaces the blueprint list rather than stacking.
--   "ai" (the character editor)    edits the blueprint's `char.ai` directly, so a rule written here is
--                                  written straight back out to data/characters/ (tools/write_character).
--
-- Either way it edits only that one channel; it never shows the item-borne or posture-default rules,
-- because a list mixing "rules you wrote" with "rules your sword came with" would make the delete key a
-- lie. What it does show is the archetype (which posture backs the list) and the auto-battle switch
-- (whether the list ever runs at all), because a rule list with neither of those visible is a form
-- with no submit button.
--
-- Two regions, crossed with Tab / Y:
--
--   rules   -- the ordered rows: enable box, priority band, the rule as a sentence
--   fields  -- the selected rule's fields, one per line, cycled with left/right
--
-- Reordering has two idioms, because the two devices want different things and pretending otherwise
-- served neither:
--
--   keyboard / pad   pick-then-place, as the Loadout screen does it: confirm GRABS a row, up/down
--                    carries it, confirm drops it. The row moves LIVE, one step per press, because
--                    discrete input has nowhere else to show the move.
--   mouse            a real drag: the row LIFTS out of the list onto the cursor, the rows it left
--                    close up, and a gap opens between two rows showing where it will land. Nothing
--                    is mutated until the button comes up, so the drag can be abandoned with Esc.
--
-- The mouse path was first built as the keyboard one driven by a pointer -- the row swapping into
-- place as you moved over each slot. It worked and read as broken: a dragged thing has to come with
-- you and land BETWEEN things, not teleport between slots underneath a cursor it isn't attached to.
--
-- Position in this list is the rule's urgency (models/ai.lua): the player's own rules carry no
-- priority band and are scanned in the order shown, which is exactly why dragging one has to mean
-- something and has to look like it does.
--
--   local ed = TacticsEditor.new({ x, y, w, h, char = char, fonts = { ... } })

local AI = require("models.ai")
local Status = require("models.status")
local InputMode = require("input_mode")

local TacticsEditor = {}
TacticsEditor.__index = TacticsEditor

-- A rule is a flat table whose only nested member is `when`, so a one-level-deep copy is a full clone.
-- Used to seed the player's overlay from the blueprint without either list aliasing the other's rules.
local function copyRule(rule)
    local out = {}
    for k, v in pairs(rule) do
        if type(v) == "table" then
            local inner = {}
            for k2, v2 in pairs(v) do inner[k2] = v2 end
            out[k] = inner
        else
            out[k] = v
        end
    end
    return out
end

-- Tall enough for the two stacked lines a row carries (the priority band, then the rule as a
-- sentence) with the sentence's descenders clear of the row edge.
local ROW_H = 42
local ROW_GAP = 5
local DELETE_W = 26 -- reserved on the right, so a long rule wraps short of the x rather than under it
local BOX = 16          -- the enable checkbox
local FIELD_H = 28
local ARROW_W = 18
-- The open option list. Capped at eight rows because the longest list in the editor is the status
-- vocabulary (seventy-odd), and a list that covers the whole column is a modal wearing a dropdown's
-- clothes; past eight it scrolls.
local DD_ROW_H = 22
local DD_MAX_ROWS = 8
-- How far the pointer must travel before a press on a row becomes a drag rather than a click. Same
-- threshold the Loadout grid and the formation grid use, so a twitchy click means the same thing on
-- every screen that carries something.
local DRAG_THRESHOLD = 4

-- Row tints. A disabled rule is drawn dim rather than hidden, so the list keeps its shape while the
-- player toggles rows to work out which one is misbehaving.
local C_ROW      = { 0.17, 0.18, 0.24 }
local C_ROW_SEL  = { 0.24, 0.27, 0.36 }
local C_ROW_GRAB = { 0.32, 0.30, 0.18 }
local C_TEXT     = { 0.86, 0.88, 0.94 }
local C_TEXT_OFF = { 0.46, 0.48, 0.54 }
local C_ACCENT   = { 0.98, 0.82, 0.30 }
local C_DIM      = { 0.62, 0.65, 0.74 }

-- ---------------------------------------------------------------------------
-- Field descriptors
-- ---------------------------------------------------------------------------
--
-- Every field is "read a value off the rule, cycle it through an ordered list, write it back". Held
-- as data so the draw loop, the input loop and the tests all walk the same definition instead of
-- three hand-kept copies of it.
--
-- THE ORDER OF THIS LIST IS THE ORDER ON SCREEN, and it deliberately matches the order of the
-- sentence AI.describeRule prints underneath it:
--
--   if <subject> <test> <value> then <act> <item> <targetPref>
--      \______ the trigger ______/      \____ the action ____/
--
-- Action used to sit second, straight after a Priority field, which put the whole trigger INSIDE the
-- action half: "support" and the weapon it was meant to be read against ended up four rows apart with
-- the condition wedged between them, and the panel stopped reading as the sentence it renders. Adding
-- a field means deciding which of the two clauses it belongs to and slotting it there, not appending.
--
-- There is no Priority field: a rule's urgency IS its position in the list, which is why the rows can
-- be dragged. See the source-ranking note in models/ai.lua.
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
        -- The THEN clause starts here. Everything above is the trigger.
        key = "act", label = "Action",
        options = function() return AI.ACTION_ORDER end,
        get = function(rule) return rule.act or "attack" end,
        set = function(rule, v) rule.act = v end,
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

-- Where field `i` sits. Pure, and the single layout source the draw loop, the mouse and the open
-- dropdown all measure from -- the same arrangement `rowRect` keeps for the rule rows, and for the
-- same reason: a dropdown anchored to a rect the draw pass happened to leave behind is a dropdown
-- that lands in the wrong place the first time anything is asked before a frame has run.
function TacticsEditor:fieldRect(i)
    return { x = self.editX, y = self.y + 26 + (i - 1) * (FIELD_H + 12), w = self.editW, h = FIELD_H }
end

-- The value bar within a field row: the part that is actually the control.
function TacticsEditor:fieldBar(i)
    local r = self:fieldRect(i)
    return { x = r.x, y = r.y + 13, w = r.w, h = 24 }
end

-- Where a carried row would be INSERTED if it were let go at `y` -- a position BETWEEN rows, not the
-- row underneath. That distinction is the whole difference between a drag that swaps and a drag that
-- lands somewhere: the boundary is the row's midpoint (hence the half-step), so pulling a row down
-- past half of its neighbour is what moves it past that neighbour.
--
-- Clamped to the real rules, so a row carried past the bottom lands last rather than on the "+ Add
-- rule" line, and one carried above the top lands first. Pure arithmetic over the same pitch the
-- layout uses, so it agrees with what is on screen without needing a draw pass to have run.
function TacticsEditor:insertIndexAt(y)
    local count = #self:rules()
    if count == 0 then return 1 end
    local k = math.floor((y - (self.y + 24)) / (ROW_H + ROW_GAP) + 0.5) + 1 + self.scroll
    return math.max(1, math.min(count, k))
end

-- The visual slot a rule index occupies right now, or nil for the row that is currently riding the
-- cursor (it is drawn at the pointer, not in the list).
--
-- While a row is carried it is OUT of the list: the rows it left close up behind it, and a one-row
-- gap opens at the insertion point. So index and slot stop being the same number, and everything that
-- positions a row has to go through here or the list tears.
function TacticsEditor:slotOf(i)
    local d = self.drag
    if not (d and d.active) then return i end
    if i == d.index then return nil end
    local pos = (i < d.index) and i or (i - 1) -- where it sits among the rows that remain
    if pos >= d.to then pos = pos + 1 end      -- ...then step over the gap
    return pos
end

-- The rectangle of visual slot `slot`, or nil when it is scrolled out of view.
function TacticsEditor:slotRect(slot)
    local s = slot - self.scroll
    if s < 1 or s > self:visibleRows() then return nil end
    return { x = self.x, y = self.y + 24 + (s - 1) * (ROW_H + ROW_GAP), w = self.listW, h = ROW_H }
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
    -- Which stored list this instance owns: "aiRules" (the player's overlay, the default in-game) or
    -- "ai" (the blueprint's own list, for the character editor). See the header.
    self.ownKey = opts.ownKey or "aiRules"
    self.region = "rules"
    self.cursor = 1        -- row index; #rules + 1 is the "+ Add rule" row
    self.fieldCursor = 1
    self.grabbed = nil     -- index of the row being carried by keyboard/pad, or nil
    self.drag = nil        -- { index, startX, startY, active } -- the same carry, by mouse
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
    self.drag = nil
    self.scroll = 0
end

-- The list to DISPLAY and navigate. Read-only in spirit: opening the tab and moving the cursor must
-- not take ownership, so an in-game character still on its blueprint list shows those rules without
-- yet minting an overlay. When the character editor owns `char.ai`, that IS the list.
function TacticsEditor:rules()
    local char = self.char
    if not char then return {} end
    if self.ownKey == "ai" then
        char.ai = char.ai or {}
        return char.ai
    end
    if char.aiRules then return char.aiRules end
    return char.ai or {} -- inherited blueprint rules, shown but not yet owned
end

-- The list to MUTATE. Anything that changes a rule routes through here, and here is where the player
-- takes ownership: the first edit to an inherited list copies the blueprint's rules into `aiRules`
-- (so none are lost) and every edit after lands on that saved copy. Idempotent once seeded.
function TacticsEditor:ownedRules()
    local char = self.char
    if not char then return {} end
    if self.ownKey == "ai" then
        char.ai = char.ai or {}
        return char.ai
    end
    if char.aiRules == nil then
        char.aiRules = TacticsEditor.seedFrom(char.ai)
    end
    return char.aiRules
end

-- Turn a blueprint's `ai` list into the player's overlay: the same rules, in the order they were
-- actually RUNNING in, with the authored priority band dropped.
--
-- Both halves matter. The blueprint's rules are ordered by an authored `priority` the player never
-- sees (models/ai.lua), while their own list is ordered by POSITION -- so copying the rules across in
-- declaration order would silently reorder a character the moment its owner touched the tab, and a
-- rule that had been firing first could quietly stop. Sorting on the way in is what makes taking the
-- list over a no-op until the player actually changes something.
--
-- And the band has to go, or it would sit invisibly in the save file outranking the very positions the
-- player is dragging -- a list that ignores its own order is worse than one that never offered it.
function TacticsEditor.seedFrom(rules)
    local out = {}
    for _, rule in ipairs(rules or {}) do out[#out + 1] = copyRule(rule) end

    -- Decorated sort: table.sort is not stable in Lua 5.1, and two rules sharing a band must keep the
    -- order their author wrote them in.
    local declared = {}
    for i, rule in ipairs(out) do declared[rule] = i end
    table.sort(out, function(a, b)
        local pa, pb = AI.priorityOf(a), AI.priorityOf(b)
        if pa ~= pb then return pa < pb end
        return declared[a] < declared[b]
    end)

    for _, rule in ipairs(out) do rule.priority = nil end
    return out
end

-- True when the rows on show are the blueprint's own and the player has not yet taken the list over --
-- the only state in which editing has a side effect (minting the overlay) worth telling them about.
function TacticsEditor:inherited()
    return self.ownKey ~= "ai" and self.char and self.char.aiRules == nil
        and #(self.char.ai or {}) > 0
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
    local rules = self:ownedRules()
    rules[#rules + 1] = AI.newRule()
    self.cursor = #rules
    self.fieldCursor = 1
    return rules[#rules]
end

function TacticsEditor:removeRule(index)
    local rules = self:ownedRules()
    if not rules[index] then return false end
    table.remove(rules, index)
    self.cursor = math.max(1, math.min(#rules + 1, index))
    self.grabbed = nil
    return true
end

function TacticsEditor:toggleEnabled(index)
    local rule = self:ownedRules()[index]
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
    -- An open list owns the d-pad: up/down walks the options rather than the fields behind them.
    if self.open then
        if dr ~= 0 then
            self.open.cursor = math.max(1, math.min(#self.open.options, self.open.cursor + dr))
            self:scrollDropdownToCursor()
        end
        return
    end
    if self.region == "rules" then
        if dr ~= 0 then
            if self.grabbed then
                -- Carrying a row: up/down moves the ROW, not the cursor. The two must not both
                -- happen, or the grabbed rule slides out from under the selection. The grab already
                -- took ownership, so `ownedRules` is the same list `rules` shows.
                local owned = self:ownedRules()
                local to = math.max(1, math.min(#owned, self.grabbed + dr))
                self.grabbed = TacticsEditor.moveRule(owned, self.grabbed, to)
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

-- ---------------------------------------------------------------------------
-- The option dropdown
-- ---------------------------------------------------------------------------
--
-- Stepping a field with < and > is fine for a two-option toggle and miserable for the ones that
-- matter: seven priorities, nine tests, seventy-odd statuses. So the value bar OPENS, showing the
-- whole vocabulary at once with the current pick marked -- one click to see the choices, one to take
-- one, instead of a click per step and a lap round the end if you overshoot.
--
-- Left/right still cycles in place and is deliberately kept: it is the fast path on a pad, it is what
-- the reorder prompts already teach, and a player nudging a percentage two steps should not have to
-- open a list to do it. The dropdown is the addition, not the replacement.

-- Open the list for visible field `index`, with the cursor on whatever the rule currently holds --
-- so the list opens showing where you are, and closing it without choosing changes nothing.
function TacticsEditor:openDropdown(index)
    local rule = self:selectedRule()
    if not rule then return false end
    local field = TacticsEditor.visibleFields(rule, self.char)[index]
    if not field then return false end

    local options = field.options(rule, self.char)
    if #options == 0 then return false end
    local current = field.get(rule, self.char)
    local at = 1
    for i, opt in ipairs(options) do
        if opt == current
            or (type(opt) == "number" and type(current) == "number" and math.abs(opt - current) < 1e-6) then
            at = i
            break
        end
    end

    self.region = "fields"
    self.fieldCursor = index
    self.open = { field = index, options = options, cursor = at,
                  scroll = math.max(0, math.min(at - 1, at - DD_MAX_ROWS + 1)) }
    return true
end

function TacticsEditor:closeDropdown()
    if not self.open then return false end
    self.open = nil
    return true
end

-- Take the option under the dropdown's cursor (or `pick`, when the mouse names one). Writes through
-- `ownedRules`, so choosing from the list takes the list over exactly as cycling it does.
function TacticsEditor:chooseOption(pick)
    local open = self.open
    if not open then return false end
    local rule = self:ownedRules()[self.cursor]
    if rule then
        local field = TacticsEditor.visibleFields(rule, self.char)[open.field]
        local value = open.options[pick or open.cursor]
        if field and value ~= nil then field.set(rule, value, self.char) end
    end
    self.open = nil
    -- Setting `act` or `test` changes which fields exist at all, so the cursor can be left pointing
    -- past the end of a list that just got shorter.
    local count = #TacticsEditor.visibleFields(self:selectedRule(), self.char)
    self.fieldCursor = math.max(1, math.min(math.max(1, count), self.fieldCursor))
    return true
end

-- Where the open list is drawn. Below its field by preference, flipped above when there is no room
-- below -- the lower fields sit near the panel edge, and a list that ran off it could not be clicked.
--
-- When the list fits NEITHER side whole, it takes the roomier side and shows as many rows as actually
-- fit there, scrolling for the rest. It must never simply be clamped into place: that slides it back
-- over the bar it belongs to, hiding the current value at the exact moment the player is choosing
-- against it.
function TacticsEditor:dropdownRect()
    local open = self.open
    if not open then return nil end
    local bar = self:fieldBar(open.field)
    local wanted = math.min(#open.options, DD_MAX_ROWS)
    local below = (self.y + self.h) - (bar.y + bar.h + 2)
    local above = (bar.y - 2) - self.y
    local function fits(space) return math.floor((space - 6) / DD_ROW_H) end

    local rows, y = wanted, nil
    if fits(below) >= wanted then
        y = bar.y + bar.h + 2
    elseif fits(above) >= wanted then
        y = bar.y - (wanted * DD_ROW_H + 6) - 2
    elseif below >= above then
        rows = math.max(1, math.min(wanted, fits(below)))
        y = bar.y + bar.h + 2
    else
        rows = math.max(1, math.min(wanted, fits(above)))
        y = bar.y - (rows * DD_ROW_H + 6) - 2
    end
    return { x = bar.x, y = y, w = bar.w, h = rows * DD_ROW_H + 6, rows = rows }
end

-- How many option rows are actually on show. The window can be smaller than DD_MAX_ROWS on a short
-- panel, and the scroll clamps have to agree with what is drawn or the cursor walks off the list.
function TacticsEditor:dropdownRows()
    local r = self:dropdownRect()
    return r and r.rows or DD_MAX_ROWS
end

-- Which option row a pointer is over, or nil when it is off the list.
function TacticsEditor:dropdownIndexAt(x, y)
    local open, r = self.open, self:dropdownRect()
    if not (open and r) then return nil end
    if x < r.x or x > r.x + r.w or y < r.y + 3 or y > r.y + r.h - 3 then return nil end
    local slot = math.floor((y - (r.y + 3)) / DD_ROW_H) + 1
    local index = slot + open.scroll
    if index < 1 or index > #open.options then return nil end
    return index
end

-- Keep the dropdown cursor inside its own window.
function TacticsEditor:scrollDropdownToCursor()
    local open = self.open
    if not open then return end
    local rows = self:dropdownRows()
    if open.cursor - 1 < open.scroll then
        open.scroll = open.cursor - 1
    elseif open.cursor > open.scroll + rows then
        open.scroll = open.cursor - rows
    end
    open.scroll = math.max(0, math.min(math.max(0, #open.options - rows), open.scroll))
end

function TacticsEditor:cycleField(dir)
    -- Editing a field's value is a mutation, so it reads from the OWNED list -- which seeds the
    -- player's overlay from the blueprint on the first edit and returns the same rule the display is
    -- pointing at (seeding preserves order, so the cursor still lands on it).
    local rule = self:ownedRules()[self.cursor]
    if not rule then return end
    local fields = TacticsEditor.visibleFields(rule, self.char)
    local field = fields[self.fieldCursor]
    if not field then return end
    field.set(rule, TacticsEditor.cycle(field.options(rule, self.char), field.get(rule, self.char), dir),
        self.char)
end

-- Confirm on the focused region. On a rule row this grabs/drops it (reorder); on the add row it adds.
function TacticsEditor:confirm()
    if self.open then self:chooseOption() return end
    if self.region == "fields" then
        -- Confirm OPENS the list rather than nudging the value one step. Stepping is still on
        -- left/right, where a player already reaching for a small change will look for it.
        self:openDropdown(self.fieldCursor)
        return
    end
    local rules = self:rules()
    if self.cursor > #rules then
        self:addRule()
        return
    end
    if self.grabbed == self.cursor then
        self.grabbed = nil
    else
        self:ownedRules() -- grabbing a row to reorder is an edit; take ownership before the move
        self.grabbed = self.cursor
    end
end

function TacticsEditor:cancel()
    -- Report whether there was something to cancel, so the panel knows whether Esc should also close
    -- it (the same contract InventoryGrid:cancelPickup keeps).
    -- The open list is the innermost thing on screen, so it is the first thing Esc takes back --
    -- and it closes WITHOUT choosing, which is what makes browsing the options free.
    if self:closeDropdown() then return true end
    -- A mouse carry can be abandoned mid-air, because nothing has moved yet -- the row simply drops
    -- back where it came from. The keyboard grab below cannot offer that: it reorders as it walks.
    if self.drag and self.drag.active then self.drag = nil return true end
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
    local slot = self:slotOf(i)
    return slot and self:slotRect(slot) or nil
end

-- Where the carried row is drawn: under the cursor, holding the exact point of itself that was
-- grabbed, so it does not jump to centre on the pointer the instant the drag starts. Clamped to the
-- list column, because a row dragged off the side and released is a row nobody can see land.
function TacticsEditor:draggedRect()
    local d = self.drag
    if not (d and d.active) then return nil end
    local top = self.y + 24
    local bottom = top + self:visibleRows() * (ROW_H + ROW_GAP) - ROW_GAP
    local y = math.max(top - ROW_H / 2, math.min(bottom - ROW_H / 2, (self.my or top) - d.offsetY))
    return { x = self.x, y = y, w = self.listW, h = ROW_H }
end

function TacticsEditor:draw()
    local f = self.fonts
    local rules = self:rules()

    love.graphics.setFont(f.small)
    setColor(C_DIM)
    -- When the rows are still the blueprint's, say so and say what touching them does -- the one edit
    -- with a side effect (minting the player's overlay) the player should not meet by surprise.
    local header = self:inherited()
        and ("Rules (" .. #rules .. ") -- from blueprint; editing makes them this character's own")
        or ("Rules (" .. #rules .. ") -- first match wins")
    love.graphics.print(header, self.x, self.y)

    -- The gap the carried row would drop into, drawn UNDER the rows so a row sliding over it as the
    -- list reflows covers it rather than being cut by it.
    self:drawDropGap()

    self.rowRects = {}
    for i = 1, self:rowCount() do
        local r = self:rowRect(i)
        if r then
            self.rowRects[i] = r
            -- Labelled by SLOT, not index: mid-drag the slot is where this row is about to end up.
            if i > #rules then self:drawAddRow(r, i) else self:drawRuleRow(r, i, rules[i], self:slotOf(i)) end
        end
    end

    -- ...and the carried row itself last of all, so it rides over the list it came out of.
    self:drawDraggedRow()

    self:drawFooter()
    self:drawFields()
    love.graphics.setColor(1, 1, 1)
end

-- The landing place: an outlined slot where the row will go if it is released now. Empty rather than
-- filled, because it is a hole in the list and should read as one.
function TacticsEditor:drawDropGap()
    local d = self.drag
    if not (d and d.active) then return end
    local r = self:slotRect(d.to)
    if not r then return end
    setColor(C_ACCENT, 0.16)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    setColor(C_ACCENT, 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setLineWidth(1)
end

-- The row riding the cursor. Drawn with a drop shadow and nudged right, so it reads as lifted OFF the
-- list rather than as a row that has wandered out of alignment.
function TacticsEditor:drawDraggedRow()
    local d = self.drag
    if not (d and d.active) then return end
    local r = self:draggedRect()
    local rule = self:rules()[d.index]
    if not (r and rule) then return end

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", r.x + 5, r.y + 5, r.w, r.h, 5, 5)
    -- Numbered by where it is GOING, so the carried row and the gap it is over agree.
    self:drawRuleRow({ x = r.x + 3, y = r.y, w = r.w, h = r.h }, d.index, rule, d.to)
end

-- `i` is the rule's index in the list; `num` is the position to LABEL it with, which during a drag is
-- where it would end up rather than where it currently is. They differ only mid-carry, and keeping
-- them apart is what lets the numbers count correctly while the list is still parting.
function TacticsEditor:drawRuleRow(r, i, rule, num)
    local f = self.fonts
    local selected = (self.region == "rules" and self.cursor == i)
    local on = rule.enabled ~= false
    -- Carried by either hand: the d-pad grab and the mouse drag are one state to the eye, because
    -- they are one state to the list.
    local held = self.grabbed == i or (self.drag and self.drag.active and self.drag.index == i)

    setColor(held and C_ROW_GRAB or (selected and C_ROW_SEL or C_ROW))
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    if selected then
        setColor(C_ACCENT, held and 1 or 0.7)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    end

    -- Enable checkbox.
    local bx, by = r.x + 8, r.y + (r.h - BOX) / 2
    setColor(on and C_ACCENT or C_TEXT_OFF)
    love.graphics.rectangle("line", bx, by, BOX, BOX, 3, 3)
    if on then love.graphics.rectangle("fill", bx + 4, by + 4, BOX - 8, BOX - 8, 2, 2) end

    -- The row's ordinal, which for a player's list IS its urgency: rules are scanned top to bottom and
    -- the first match takes the turn, so "3" is the whole answer to "when does this one get looked
    -- at". Drawn where the old priority band used to sit, because it now says what that said.
    local px = bx + BOX + 10
    setColor(C_ACCENT, on and 0.9 or 0.35)
    love.graphics.rectangle("fill", px, r.y + 6, 4, r.h - 12, 2, 2)

    love.graphics.setFont(f.tiny)
    setColor(C_DIM, on and 1 or 0.4)
    love.graphics.print(tostring(num or i), px + 10, r.y + 5)

    -- The rule as a sentence. Width-clamped short of the delete button and clipped to one line: a
    -- rule long enough to wrap would otherwise grow the row out of its own rectangle.
    local textX = px + 10
    local textW = (r.x + r.w - DELETE_W) - textX
    love.graphics.setFont(f.small)

    -- A rule naming an item the character isn't carrying can never fire. Flagged on the ROW, not
    -- only in the field editor: the player has to be able to see which of ten rules is dead without
    -- selecting each one in turn.
    local dormant = rule.item and not AI.resolveItem(self.char or {}, rule.item)
    setColor(dormant and { 0.95, 0.55, 0.5 } or (on and C_TEXT or C_TEXT_OFF))
    local text = AI.describeRule(rule)
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
        local opened = self.open and self.open.field == i
        local r = self:fieldRect(i)
        self.fieldRects[i] = r
        y = r.y

        love.graphics.setFont(f.tiny)
        setColor(C_DIM)
        love.graphics.print(field.label, r.x, r.y)

        local vy = r.y + 13
        setColor((selected or opened) and C_ROW_SEL or C_ROW)
        love.graphics.rectangle("fill", r.x, vy, r.w, 24, 4, 4)
        if selected or opened then
            setColor(C_ACCENT, opened and 1 or 0.7)
            love.graphics.rectangle("line", r.x, vy, r.w, 24, 4, 4)
        end

        -- One caret on the right, the way every dropdown anywhere says "there is a list under me".
        -- It flips while the list is up, so the control shows its own state.
        love.graphics.setFont(f.small)
        setColor((opened or self.hoverField == i) and C_ACCENT or C_DIM)
        love.graphics.printf(opened and "^" or "v", r.x + r.w - ARROW_W - 4, vy + 4, ARROW_W, "center")

        -- A rule pinned to an item the character is no longer carrying is dormant, and the field says
        -- so in place rather than showing a name that implies it will fire.
        local value = field.get(rule, self.char)
        local dormant = field.key == "item" and value
            and not AI.resolveItem(self.char or {}, value)
        setColor(dormant and { 0.95, 0.55, 0.5 } or C_TEXT)
        local label = optionLabel(field, rule, value, self.char)
        if dormant then label = label .. " (not carried)" end
        love.graphics.printf(label, r.x + 8, vy + 4, r.w - ARROW_W - 16, "center")

        y = r.y + FIELD_H + 12
    end

    -- The finished sentence, so the player can read what they built without decoding six fields.
    love.graphics.setFont(f.tiny)
    setColor(C_DIM)
    love.graphics.printf(AI.describeRule(rule), self.editX, y + 6, self.editW, "left")

    -- Last, so it covers the fields it overlaps rather than being covered by them.
    self:drawDropdown(rule, fields)
end

function TacticsEditor:drawDropdown(rule, fields)
    local open, r = self.open, self:dropdownRect()
    if not (open and r) then return end
    local field = fields[open.field]
    if not field then return end
    local f = self.fonts

    -- An opaque plate with a border: the list sits ON the panel, and a translucent one over a row of
    -- other fields is unreadable at exactly the moment it has to be read.
    setColor({ 0.10, 0.11, 0.15 })
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    setColor(C_ACCENT, 0.8)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)

    love.graphics.setFont(f.small)
    local current = field.get(rule, self.char)
    for slot = 1, r.rows do
        local index = slot + open.scroll
        local value = open.options[index]
        if value ~= nil then
            local ry = r.y + 3 + (slot - 1) * DD_ROW_H
            local onCursor = index == open.cursor
            if onCursor then
                setColor(C_ROW_SEL)
                love.graphics.rectangle("fill", r.x + 2, ry, r.w - 4, DD_ROW_H, 3, 3)
            end
            -- The value the rule actually holds keeps a marker of its own, so an open list always
            -- says where you are as well as where you are pointing.
            local isCurrent = value == current
                or (type(value) == "number" and type(current) == "number"
                    and math.abs(value - current) < 1e-6)
            if isCurrent then
                setColor(C_ACCENT)
                love.graphics.print("*", r.x + 6, ry + 3)
            end
            setColor(onCursor and C_ACCENT or C_TEXT)
            love.graphics.print(optionLabel(field, rule, value, self.char), r.x + 18, ry + 3)
        end
    end

    -- A plain "there is more below/above" mark. The window is capped and the status vocabulary is
    -- seventy long, so without this the cap reads as the whole vocabulary.
    if #open.options > r.rows then
        love.graphics.setFont(f.tiny)
        setColor(C_DIM)
        love.graphics.printf(open.scroll + r.rows .. "/" .. #open.options,
            r.x, r.y + r.h - 12, r.w - 6, "right")
    end
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
    self.mx, self.my = x, y

    -- A press that has travelled far enough becomes a carry. From then on the row is LIFTED -- drawn
    -- at the cursor, out of the list, with a gap where it would land -- and the list itself is not
    -- touched until the drop. Nothing is mutated on the way, which is what lets Esc abandon a drag and
    -- lets an inherited blueprint list stay inherited unless the row is actually moved.
    if self.drag then
        if not self.drag.active
            and (math.abs(x - self.drag.startX) > DRAG_THRESHOLD
                or math.abs(y - self.drag.startY) > DRAG_THRESHOLD) then
            self.drag.active = true
            self.grabbed = nil -- a mouse carry supersedes a keyboard one; only one row travels at a time
            -- Where in the row it was picked up, so the row hangs off the cursor at the point the
            -- player actually grabbed rather than snapping its top-left to the pointer.
            local r = self:slotRect(self.drag.index)
            self.drag.offsetY = r and (self.drag.startY - r.y) or ROW_H / 2
        end
        if self.drag.active then
            -- Measured from the CARRIED ROW's top edge, not from the pointer. Off the raw pointer the
            -- gap opens a row away from the thing being dragged -- you hold a row over one place and
            -- the list parts somewhere else, which reads as lag. Off the row's own edge the gap is
            -- simply the slot the row is nearest to filling, whatever point of it was grabbed --
            -- `insertIndexAt` already rounds to the nearest gap, so no half-row is added here.
            self.drag.to = self:insertIndexAt(y - self.drag.offsetY)
            return
        end
    end

    self.hoverRow, self.hoverDelete, self.hoverField, self.hoverArrow = nil, nil, nil, nil
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) then
            self.hoverRow = i
            if x >= r.x + r.w - DELETE_W then self.hoverDelete = i end
        end
    end
    -- Hovering an open list moves its cursor, so the row under the pointer is the row that a click
    -- takes -- and so the keyboard and the mouse are never pointing at two different options.
    if self.open then
        local over = self:dropdownIndexAt(x, y)
        if over then self.open.cursor = over end
        return
    end

    for i in pairs(self.fieldRects) do
        if hit(self:fieldBar(i), x, y) then self.hoverField = i end
    end
end

-- Returns true when the click was consumed, so the panel knows not to treat it as a click-outside.
function TacticsEditor:mousepressed(x, y)
    -- An open list is modal over the editor: it takes the click, whether that click chooses an
    -- option or dismisses it. Swallowed either way, so the click that closes a list can't also land
    -- on whatever happened to be underneath it.
    if self.open then
        local pick = self:dropdownIndexAt(x, y)
        if pick then self:chooseOption(pick) else self:closeDropdown() end
        return true
    end

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
                -- Arm a carry. It is not one yet -- a press that never travels is just this
                -- selection, which has already happened on the line above.
                self.drag = { index = i, startX = x, startY = y, active = false }
            end
            return true
        end
    end

    for i in pairs(self.fieldRects) do
        if hit(self:fieldBar(i), x, y) then
            -- The whole bar is the control now. There is no step-by-one click target left, which is
            -- the point: one click shows every option instead of advancing by one.
            self.region = "fields"
            self.fieldCursor = i
            self:openDropdown(i)
            return true
        end
    end
    return false
end

-- Let go. THIS is where the reorder happens -- the drag itself only moved a picture around, so this
-- is the single point at which the list changes and the single point at which the player takes
-- ownership of an inherited one. Returns true when a carry ended, so the host can tell a drop from a
-- click.
function TacticsEditor:mousereleased()
    local d = self.drag
    self.drag = nil
    if not (d and d.active) then return false end
    -- Dropping a row back where it came from is not an edit, and must not mint an overlay.
    if d.to ~= d.index then
        self.cursor = TacticsEditor.moveRule(self:ownedRules(), d.index, d.to)
    else
        self.cursor = d.index
    end
    return true
end

function TacticsEditor:wheelmoved(dy)
    -- The wheel belongs to whatever is on top: an open list scrolls itself, not the rules behind it.
    if self.open then
        local maxScroll = math.max(0, #self.open.options - self:dropdownRows())
        self.open.scroll = math.max(0, math.min(maxScroll, self.open.scroll - dy))
        return
    end
    local maxScroll = math.max(0, self:rowCount() - self:visibleRows())
    self.scroll = math.max(0, math.min(maxScroll, self.scroll - dy))
end

function TacticsEditor:cursorKind(x, y)
    if self.open then return self:dropdownIndexAt(x, y) and "hand" or "arrow" end
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
    if self.open then
        add(pad and "D-pad" or "Up/Down", "Pick")
        add(pad and "A" or "Enter", "Choose")
        add(pad and "B" or "Esc", "Cancel")
    elseif self.region == "fields" then
        add(pad and "A" or "Enter", "Open list")
        add(pad and "D-pad" or "Left/Right", "Step")
        add(pad and "Y" or "Tab", "Back to rules")
    elseif self.drag and self.drag.active then
        -- A mouse carry has its own two verbs, and "release to drop" is worth saying because the row
        -- has left the list and the player is holding something.
        add("Release", "Drop here")
        add("Esc", "Cancel")
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
