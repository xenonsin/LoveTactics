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
-- Three regions, crossed with Tab / Y:
--
--   rules   -- the ordered rows: enable box, priority band, the rule as a sentence
--   fields  -- the selected rule's fields, one per line, cycled with left/right
--   footer  -- the strip under the list: archetype, auto-battle, and the reset
--
-- The footer used to be mouse-only, which made two of the three things this tab decides unreachable
-- on a pad. It walks like the field column does -- up/down picks a control, left/right changes it --
-- because that is the idiom the region next door already teaches.
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
-- The reset control, parked at the far right of the footer strip -- as far from the archetype and
-- auto-battle switches as the strip allows, because it is the one control down there that throws work
-- away rather than changing a setting.
local RESET_W = 150
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

-- The archetype control in the footer strip. Computed rather than left behind by `drawFooter` for the
-- same reason the field rects are: it is what the archetype list anchors to, and a list measured off
-- last frame's rectangle lands in the wrong place the first time it is opened.
function TacticsEditor:archetypeRect()
    return { x = self.x, y = self.footY + 14, w = 180, h = 24 }
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
    self.footCursor = 1    -- which footer control has focus (see footControls)
    self.resetArmed = false -- the reset's first press; the second one carries it out
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
    self.footCursor = 1
    self.resetArmed = false -- an armed reset must never survive onto the next character
    self.grabbed = nil
    self.drag = nil
    self.open = nil -- nor may an open list: it was opened against the last character's value
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

-- The postures on offer, in the order they are shown. `false` ("default") leads, because it is a real,
-- reachable option and not an absence -- a player who tried an archetype and wants out again has to be
-- able to get back to it. The list and the stepper below read the SAME order, so opening the list
-- never reshuffles the thing left/right was walking.
function TacticsEditor.archetypeOptions()
    local out = { false }
    for _, name in ipairs(AI.POSTURE_ORDER) do out[#out + 1] = name end
    return out
end

function TacticsEditor:cycleArchetype(dir)
    local char = self.char
    if not char then return end
    char.archetype = TacticsEditor.cycle(TacticsEditor.archetypeOptions(), char.archetype or false, dir)
        or nil
end

-- The posture explained, as the tooltip beside the open list wants it: a title and paragraphs.
--
-- "default" is not a posture and has no `desc` of its own, so it borrows the one it falls back to --
-- said in two paragraphs rather than one, because "you have not chosen" and "so this is what happens"
-- are two different facts and a player reading the first still needs the second.
function TacticsEditor.archetypeHelp(value)
    if not value then
        local fallback = AI.POSTURES[AI.DEFAULT_POSTURE]
        return AI.postureLabel(false), {
            "No posture of its own, so it stands on the one every body falls back to -- "
                .. AI.postureLabel(AI.DEFAULT_POSTURE) .. ".",
            fallback and fallback.desc or "",
        }
    end
    local posture = AI.POSTURES[value]
    if not (posture and posture.desc) then return nil end
    return AI.postureLabel(value), { posture.desc }
end

function TacticsEditor:toggleAuto()
    local char = self.char
    if not char then return end
    char.autoBattle = not char.autoBattle
end

-- ---------------------------------------------------------------------------
-- Reset to defaults
-- ---------------------------------------------------------------------------
--
-- Everything this tab changes is an overlay on top of what the character was BUILT as, and this puts
-- all of it back: the rule list, the archetype behind it, and the auto-battle switch. Without it the
-- only way out of a rule list you have made a mess of is to delete the rules one at a time -- and even
-- then you land on an EMPTY list, not on the one the character shipped with, which is gone the moment
-- the overlay is minted.

-- The blueprint this character was instantiated from, or nil for a body with no registry entry.
-- "Defaults" means what data/characters/<id>.lua says, so with no blueprint there is nothing to go
-- back to and the control stays out of the way. Required lazily: models/character loads the whole
-- character registry, and this widget is required by the headless tests.
function TacticsEditor:blueprint()
    local char = self.char
    if not (char and char.id) then return nil end
    return require("models.character").defs[char.id]
end

-- Whether there is anything to put back. Drawn dim and inert when there is not, rather than hidden:
-- a control that comes and goes is one the player has to find twice.
function TacticsEditor:canReset()
    -- The character editor IS where defaults are written (it edits `char.ai` straight back out to
    -- data/characters/), so it has nothing behind it to restore.
    if self.ownKey == "ai" then return false end
    local char, def = self.char, self:blueprint()
    if not (char and def) then return false end
    if char.aiRules ~= nil then return true end
    if char.autoBattle then return true end
    return char.archetype ~= def.archetype
end

-- Put the character back on its blueprint. Note what this does NOT do: it does not copy the
-- blueprint's rules into the overlay, it DROPS the overlay -- so the list comes back inherited, in
-- exactly the state it was in before anybody opened this tab, and the save stops carrying it
-- (models/save.lua writes `aiRules` only when it exists).
function TacticsEditor:resetToDefaults()
    if not self:canReset() then return false end
    local char, def = self.char, self:blueprint()
    char.aiRules = nil
    char.archetype = def.archetype
    char.autoBattle = nil
    -- The list underneath just changed length; anything pointing into the old one is stale.
    self.cursor, self.fieldCursor, self.scroll = 1, 1, 0
    self.grabbed, self.drag, self.open = nil, nil, nil
    self.resetArmed = false
    return true
end

-- The reset takes two presses: the first ARMS it, the second carries it out. A rule list is minutes of
-- work and this throws all of it away, so it does not hang off one click -- and the armed state is
-- dropped by any other input at all (disarmReset), so it can never fire late on a player who armed it,
-- went elsewhere and came back.
function TacticsEditor:pressReset()
    if not self:canReset() then return false end
    if not self.resetArmed then
        self.resetArmed = true
        return false
    end
    return self:resetToDefaults()
end

function TacticsEditor:disarmReset()
    if not self.resetArmed then return false end
    self.resetArmed = false
    return true
end

-- The footer controls, in the order the region walks them.
function TacticsEditor:footControls()
    if self.ownKey == "ai" then return { "archetype", "auto" } end
    return { "archetype", "auto", "reset" }
end

function TacticsEditor:footControl()
    return self:footControls()[self.footCursor]
end

-- Put the footer cursor on a named control. By NAME rather than by number, because the strip is two
-- controls long in the character editor and three in game, and a click that focused "the third one"
-- would point at nothing on one of them.
function TacticsEditor:focusFooter(control)
    self.region = "footer"
    for i, name in ipairs(self:footControls()) do
        if name == control then self.footCursor = i return end
    end
end

-- Left/right on the focused footer control: the same "step the value in place" the field column
-- gives, for the two controls that have a value to step.
function TacticsEditor:adjustFooter(dir)
    local control = self:footControl()
    if control == "archetype" then self:cycleArchetype(dir) end
    if control == "auto" then self:toggleAuto() end
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
    self:disarmReset()
    if self.region == "footer" then
        local controls = self:footControls()
        if dr ~= 0 then
            self.footCursor = math.max(1, math.min(#controls, self.footCursor + dr))
        end
        if dc ~= 0 then self:adjustFooter(dc) end
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
--
-- The same list serves the footer's ARCHETYPE, which is why `open` carries a `source` instead of just
-- a field index. A posture list has the field lists' problem twice over: eight names, none of which
-- says what it does, so stepping it blind means trying all eight to find out what they were.

-- Which option a list should open ON: where the value already is, so it opens showing where you are
-- and closing it without choosing changes nothing.
local function indexOf(options, current)
    for i, opt in ipairs(options) do
        if opt == current
            or (type(opt) == "number" and type(current) == "number" and math.abs(opt - current) < 1e-6) then
            return i
        end
    end
    return 1
end

-- Open the list for visible field `index`.
function TacticsEditor:openDropdown(index)
    local rule = self:selectedRule()
    if not rule then return false end
    local field = TacticsEditor.visibleFields(rule, self.char)[index]
    if not field then return false end

    local options = field.options(rule, self.char)
    if #options == 0 then return false end
    local at = indexOf(options, field.get(rule, self.char))

    self.region = "fields"
    self.fieldCursor = index
    self.open = { source = "field", field = index, options = options, cursor = at,
                  scroll = math.max(0, math.min(at - 1, at - DD_MAX_ROWS + 1)) }
    return true
end

-- Open the archetype list off the footer control. Shown WHOLE (`maxRows` is the whole vocabulary, not
-- DD_MAX_ROWS): the postures are nine including "default" and they fit, and a list that scrolls one
-- row hides an option the player is choosing between while telling them nothing about the cap.
function TacticsEditor:openArchetype()
    if not self.char then return false end
    local options = TacticsEditor.archetypeOptions()
    self:focusFooter("archetype")
    self.open = { source = "archetype", options = options, maxRows = #options,
                  cursor = indexOf(options, self.char.archetype or false), scroll = 0 }
    self:scrollDropdownToCursor()
    return true
end

-- Which visible field the open list belongs to, or nil when it is the footer's. Everything that draws
-- a field asks this rather than reading `open.field`, so the archetype list cannot light up a field
-- bar that has nothing to do with it.
function TacticsEditor:openFieldIndex()
    local open = self.open
    return open and open.source ~= "archetype" and open.field or nil
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
    if open.source == "archetype" then
        local value = open.options[pick or open.cursor]
        self.open = nil
        -- `false` is the option, nil is the storage: an archetype that matches the default is an
        -- absence in the character, which is what makes `canReset` and the save file agree.
        if self.char and value ~= nil then self.char.archetype = value or nil end
        return true
    end
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
-- The control the open list hangs off: a field's value bar, or the archetype box down in the footer.
-- Both are computed, not remembered from the last draw, for the reason `fieldRect` gives.
function TacticsEditor:dropdownAnchor()
    local open = self.open
    if not open then return nil end
    if open.source == "archetype" then return self:archetypeRect() end
    return self:fieldBar(open.field)
end

function TacticsEditor:dropdownRect()
    local open = self.open
    if not open then return nil end
    local bar = self:dropdownAnchor()
    local wanted = math.min(#open.options, open.maxRows or DD_MAX_ROWS)
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
    if r then return r.rows end
    return (self.open and self.open.maxRows) or DD_MAX_ROWS
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
    if self.region == "footer" then
        local control = self:footControl()
        -- Only the reset keeps its armed state across a confirm; the other two disarm it like any
        -- other input would.
        if control == "reset" then self:pressReset() return end
        self:disarmReset()
        -- Confirm OPENS the archetype list, exactly as it opens a field's -- the footer is the same
        -- kind of choice as the column next door, and the eight postures are the list this tab most
        -- needs to show whole. Left/right still steps it in place.
        if control == "auto" then self:toggleAuto() else self:openArchetype() end
        return
    end
    self:disarmReset()
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
    -- An armed reset is the most recent thing the player did and the only one that is waiting on them,
    -- so Esc takes that back first -- and swallows the press, because backing out of a reset must not
    -- also close the panel.
    if self:disarmReset() then return true end
    -- The open list is the innermost thing on screen, so it is the next thing Esc takes back --
    -- and it closes WITHOUT choosing, which is what makes browsing the options free.
    if self:closeDropdown() then return true end
    -- A mouse carry can be abandoned mid-air, because nothing has moved yet -- the row simply drops
    -- back where it came from. The keyboard grab below cannot offer that: it reorders as it walks.
    if self.drag and self.drag.active then self.drag = nil return true end
    if self.grabbed then self.grabbed = nil return true end
    if self.region ~= "rules" then self.region = "rules" return true end
    return false
end

local REGION_ORDER = { "rules", "fields", "footer" }

-- Column-editor contract (see Party:columnEditor). The host walks Tab through the editor's own regions
-- before handing focus back out; it learns the walk is over from the RETURN VALUE rather than by
-- knowing how many regions this particular editor has, which is what let a third one be added here
-- without the host learning its name.
function TacticsEditor:cycleRegion()
    self:disarmReset()
    -- An open list belongs to the control it was opened from; leaving that control closes it, rather
    -- than leaving a list hanging over a region that no longer has the focus.
    self:closeDropdown()
    local at = 1
    for i, r in ipairs(REGION_ORDER) do if r == self.region then at = i end end
    repeat
        at = at + 1
        -- The field column is empty when no rule is selected, and a Tab stop with nothing in it is a
        -- dead press.
    until at > #REGION_ORDER or REGION_ORDER[at] ~= "fields" or self:selectedRule()
    if at > #REGION_ORDER then
        self.region = "rules" -- wrapped: back to the top, and the host takes the focus away
        return false
    end
    self.region = REGION_ORDER[at]
    if self.region == "footer" then
        self.footCursor = math.max(1, math.min(#self:footControls(), self.footCursor))
    end
    return true
end

function TacticsEditor:isFirstRegion()
    return self.region == "rules"
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
    -- Last of everything, because it now opens off either column and has to cover both -- and because
    -- the footer's list has to be drawn even on the frames where `drawFields` returns early.
    self:drawDropdown()
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

-- Archetype + auto-battle + reset. These frame the whole list: the archetype is what backs it when no
-- rule matches, auto-battle is whether any of it runs at all, and the reset takes all three back to
-- what the character was built with.
function TacticsEditor:drawFooter()
    local f = self.fonts
    local char = self.char
    if not char then return end
    local focused = self.region == "footer" and self:footControl() or nil

    -- One ring, drawn the same way round every footer control, so the region reads as one strip with
    -- a cursor in it rather than three unrelated widgets.
    local function ring(r, on)
        if not on then return end
        setColor(C_ACCENT, 0.8)
        love.graphics.rectangle("line", r.x - 2, r.y - 2, r.w + 4, r.h + 4, 5, 5)
    end

    love.graphics.setFont(f.tiny)
    setColor(C_DIM)
    -- Held clear of the boxes by more than the focus ring is thick, so a ringed control does not
    -- underline its own label.
    love.graphics.print("Archetype", self.x, self.footY - 3)
    love.graphics.print("Auto-battle", self.x + 200, self.footY - 3)

    -- The archetype control is a dropdown, drawn as the field bars next door are drawn: a plate, the
    -- value, and one caret saying there is a list under it. It used to wear "< name >", which was a
    -- stepper -- and a stepper through eight postures whose names do not say what they do means
    -- visiting all eight to find out what the first one was.
    local r = self:archetypeRect()
    self.archRect = r
    local opened = self.open and self.open.source == "archetype"
    setColor((focused == "archetype" or opened) and C_ROW_SEL or C_ROW)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)

    love.graphics.setFont(f.small)
    setColor((opened or self.hoverArch) and C_ACCENT or C_DIM)
    love.graphics.printf(opened and "^" or "v", r.x + r.w - ARROW_W - 4, r.y + 4, ARROW_W, "center")
    setColor(C_TEXT)
    love.graphics.printf(AI.postureLabel(char.archetype), r.x + 8, r.y + 4, r.w - ARROW_W - 16, "center")
    ring(r, focused == "archetype")

    self.autoRect = { x = self.x + 200, y = self.footY + 14, w = 90, h = 24 }
    setColor(char.autoBattle and { 0.35, 0.55, 0.38 } or C_ROW)
    love.graphics.rectangle("fill", self.autoRect.x, self.autoRect.y, self.autoRect.w, self.autoRect.h, 4, 4)
    setColor(char.autoBattle and { 0.75, 0.95, 0.75 } or C_TEXT_OFF)
    love.graphics.printf(char.autoBattle and "ON" or "OFF",
        self.autoRect.x, self.autoRect.y + 4, self.autoRect.w, "center")
    ring(self.autoRect, focused == "auto")

    self:drawReset(focused == "reset", ring)

    -- Say what the switch actually does, once, where it is -- rather than nowhere. Stops short of the
    -- reset, which sits at the far end of the same line.
    love.graphics.setFont(f.tiny)
    setColor(C_DIM)
    love.graphics.printf(char.autoBattle
        and "Acts on its own turn. Press any key to take over."
        or "You control this unit in battle.",
        self.x + 300, self.footY + 18, math.max(0, self.w - 300 - RESET_W - 20), "left")
end

-- The reset control. Three states, because it is the only thing on this tab that destroys something:
-- inert (nothing to put back), ready, and ARMED -- where it says what it is about to do and waits for
-- a second press.
function TacticsEditor:drawReset(focused, ring)
    self.resetRect = nil
    if self.ownKey == "ai" then return end -- see canReset: no defaults behind the character editor

    local f = self.fonts
    local r = { x = self.x + self.w - RESET_W, y = self.footY + 14, w = RESET_W, h = 24 }
    self.resetRect = r
    local live = self:canReset()
    local armed = live and self.resetArmed

    love.graphics.setFont(f.tiny)
    setColor(C_DIM, live and 1 or 0.5)
    love.graphics.printf("Defaults", r.x, self.footY - 3, r.w, "right")

    setColor(armed and { 0.34, 0.19, 0.19 } or C_ROW, live and 1 or 0.6)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
    if armed then
        setColor({ 0.95, 0.55, 0.5 }, 0.9)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
    end

    love.graphics.setFont(f.small)
    if not live then
        setColor(C_TEXT_OFF, 0.6)
    elseif armed then
        setColor({ 0.95, 0.6, 0.55 })
    else
        setColor((focused or self.hoverReset) and C_ACCENT or C_TEXT)
    end
    love.graphics.printf(armed and "Confirm reset" or "Reset to defaults", r.x, r.y + 4, r.w, "center")
    ring(r, focused)

    -- What "defaults" covers, spelt out where the press happens rather than left to be discovered by
    -- pressing. Only while the control is live and being looked at, so the strip stays quiet the rest
    -- of the time.
    if not (live and (armed or focused or self.hoverReset)) then return end
    love.graphics.setFont(f.tiny)
    setColor(armed and { 0.95, 0.6, 0.55 } or C_DIM)
    love.graphics.printf(armed and "Discards your rules, archetype and auto-battle."
        or "Restores this character's own rules, archetype and auto-battle.",
        r.x - 320, r.y + r.h + 3, r.w + 320, "right")
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
        local opened = self:openFieldIndex() == i
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
end

-- What the open list is choosing AGAINST: the value the control behind it currently holds, and the
-- words for any option in it. Both go through the `source`, so the list widget below never learns
-- which control opened it.
function TacticsEditor:openCurrent()
    local open = self.open
    if not open then return nil end
    if open.source == "archetype" then return (self.char and self.char.archetype) or false end
    local rule = self:selectedRule()
    local field = rule and TacticsEditor.visibleFields(rule, self.char)[open.field]
    return field and field.get(rule, self.char)
end

function TacticsEditor:openLabel(value)
    local open = self.open
    if not open or open.source == "archetype" then return AI.postureLabel(value) end
    local rule = self:selectedRule()
    local field = rule and TacticsEditor.visibleFields(rule, self.char)[open.field]
    if not field then return tostring(value) end
    return optionLabel(field, rule, value, self.char)
end

function TacticsEditor:drawDropdown()
    local open, r = self.open, self:dropdownRect()
    if not (open and r) then return end
    if open.source ~= "archetype" and not self:selectedRule() then return end
    local f = self.fonts

    -- An opaque plate with a border: the list sits ON the panel, and a translucent one over a row of
    -- other fields is unreadable at exactly the moment it has to be read.
    setColor({ 0.10, 0.11, 0.15 })
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    setColor(C_ACCENT, 0.8)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)

    love.graphics.setFont(f.small)
    local current = self:openCurrent()
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
            love.graphics.print(self:openLabel(value), r.x + 18, ry + 3)
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

    self:drawOptionTooltip(r)
end

-- Three of the vocabularies are lists of IDS whose names are not self-explaining: the kit ("Using"),
-- the status list, and the postures. "Wildcraft Poultice", "Cowering" and "skirmish" are names, not
-- answers -- picking against them means knowing what they do, and a player who has to leave the screen
-- to find out will pick wrong.
--
-- So the option under the cursor explains itself, through the SAME tooltips the rest of the game
-- draws for an item and for a status. Reusing them is the point: a Healing Potion must not acquire a
-- second, thinner description that lives only here and drifts from the real one. A posture has no
-- tooltip of its own anywhere else in the game, so it borrows the plain titled-prose one -- with the
-- words themselves kept next to the behavior, in AI.POSTURES.
--
-- Required lazily, inside a draw path, because the tooltip modules reach for love.graphics and this
-- widget's logic is loaded by the headless tests.
function TacticsEditor:drawOptionTooltip(r)
    local open = self.open
    local value = open.options[open.cursor]

    if open.source == "archetype" then
        local title, paragraphs = TacticsEditor.archetypeHelp(value)
        if not title then return end
        -- Beside the list rather than over it, and to the RIGHT: this list sits against the panel's
        -- left edge, so the room is all on the other side. Held at the cursor's ROW, not at the
        -- pointer, so mouse and pad read the same and the option being explained is the one the
        -- explanation is level with.
        local ay = r.y + 3 + (open.cursor - open.scroll - 1) * DD_ROW_H
        require("ui.note_tooltip").draw(title, paragraphs, r.x + r.w - 4, ay - 16, self.x + self.w)
        return
    end

    if value == nil or value == false then return end -- "any" describes itself
    local rule = self:selectedRule()
    local field = rule and TacticsEditor.visibleFields(rule, self.char)[open.field]
    if not (rule and field) then return end

    -- Anchored to the pointer when it is genuinely over the list; otherwise beside the highlighted
    -- row, so a keyboard or pad gets the same explanation without a mouse to hang it on.
    local ax, ay = self.mx, self.my
    if not (ax and ay and self:dropdownIndexAt(ax, ay) == open.cursor) then
        ax = r.x + r.w - 12
        ay = r.y + 3 + (open.cursor - open.scroll - 1) * DD_ROW_H
    end

    -- Held clear of the list's left edge. Both tooltips flip to the left of their anchor when they
    -- would cross `maxRight`, so capping it here is what stops the explanation from covering the four
    -- options underneath the one being explained -- which is the whole set the player is choosing
    -- BETWEEN, and the last thing that should be hidden while they choose.
    local maxRight = r.x - 4

    if field.key == "item" then
        local item = AI.resolveItem(self.char or {}, value)
        -- Nil for a rule naming something no longer carried: the row already says "not carried", and
        -- there is no live item to describe.
        --
        -- No `actor`: that argument is a battle UNIT, not a character, and there is no unit on this
        -- screen. Passing one prices the ability against that body's live resources; passing none
        -- runs it against a neutral caster, which is what every other Armory hover does.
        if item then require("ui.item_tooltip").draw(item, ax, ay, maxRight, nil) end
        return
    end

    local spec = AI.TEST_VALUE[rule.when and rule.when.test or ""]
    if field.key == "value" and spec and spec.kind == "status" then
        local def = Status.defs[value]
        if def then require("ui.status_tooltip").draw({ def = def }, ax, ay, maxRight) end
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
    self.hoverReset = hit(self.resetRect, x, y) and self:canReset() or nil
    self.hoverArch = hit(self.archRect, x, y) or nil
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

    -- The reset is checked first and keeps its armed state, because it is the one control whose second
    -- click means something different from its first. Every other branch below drops the arming.
    if hit(self.resetRect, x, y) then
        self:focusFooter("reset")
        self:pressReset()
        return true
    end
    self:disarmReset()

    if hit(self.archRect, x, y) then
        -- The whole box is the control, as a field bar is: one click shows every posture with its
        -- description, rather than advancing to the next name and leaving the player to guess it.
        self:openArchetype()
        return true
    end
    if hit(self.autoRect, x, y) then
        self:focusFooter("auto")
        self:toggleAuto()
        return true
    end

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
    -- Only when it is live: a dead control that grows a hand cursor promises a click that does nothing.
    if hit(self.resetRect, x, y) and self:canReset() then return "hand" end
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
        add(pad and "Y" or "Tab", "Settings")
    elseif self.region == "footer" then
        add(pad and "D-pad" or "Up/Down", "Pick")
        if self:footControl() == "reset" then
            -- Nothing to put back means no verb: a prompt for a press that does nothing is worse than
            -- no prompt, because it reads as the reset having failed.
            if self:canReset() then
                add(pad and "A" or "Enter", self.resetArmed and "Confirm reset" or "Reset")
                if self.resetArmed then add(pad and "B" or "Esc", "Keep them") end
            end
        elseif self:footControl() == "archetype" then
            add(pad and "A" or "Enter", "Open list")
            add(pad and "D-pad" or "Left/Right", "Step")
        else
            add(pad and "D-pad" or "Left/Right", "Change")
            add(pad and "A" or "Enter", "Change")
        end
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
