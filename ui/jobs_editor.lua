-- THE ROLL, as a column of the Armory: what this body IS, and every job it could become.
--
-- The class ledger was written every fight (Growth.jobOf, Class.classLevel), persisted through
-- every save, and shown to nobody until this existed. It had its own door on the plaza for a while --
-- The Roll, the card under the Gate -- and that was one card too many for one question about a body:
-- the Armory is already the screen you open to ask what a member of the company is carrying, and what
-- it IS belongs on the same rail rather than across the square. So this is a COLUMN EDITOR
-- (see Party:columnEditor), a third view of one member beside Loadout and Tactics, and the portrait
-- rail is the roster it used to draw for itself.
--
-- TWO COLUMNS, and each answers one question:
--
--   WHAT   every job open to this body, grouped under the class it hangs off: its level, how far into
--          the next rung it is, and which one it is declared in.
--   WHY    the highlighted job in full -- what the path is and what this body has done in it.
--
-- IT IS A LIST, NOT A LATTICE, and that is a decision rather than a shortcut. Forty-five jobs across
-- seven parents with twenty-one crossings between them is a real graph, and drawn as one at 1280x720
-- it is a plate of spaghetti nobody can read a number off. FFT's own job screen is a list too, for the
-- same reason: what a player actually does here is compare a job's level against the rung above it,
-- and a list puts those two numbers on one line.
--
-- A LOCKED JOB IS NOT DRAWN AT ALL, which is the other thing taken from FFT. A body's roll is what it
-- may become NEXT, not the whole tree with forty rows greyed out -- and a list where four fifths of
-- the rows are refusals is a list the player learns to scroll past. What survives is one muted line
-- per class saying how many paths it still has behind it, so the ladder is never invisible, only
-- unnamed: the name is the thing the work is for.
--
-- A MULTICLASS IS FILED UNDER BOTH ITS PARENTS. Shopping both shelves is literally how you build one
-- (models/vendor.lua says the same about its stock), so hiding it under one parent would make half the
-- crossings invisible to a player reading down the other.
--
-- DECLARING A JOB IS THE ONE ACT HERE, and it is free and reversible. `growthBy` is gone and nothing is
-- re-apportioned when you switch (models/growth.lua) -- levels already credited are never revisited --
-- so changing your mind costs the levels ahead of you, never the ones behind. That is what makes a job
-- a decision the player can afford to make early.

local Theme = require("ui.theme")
local ProgressBar = require("ui.progress_bar")
local Class = require("models.class")
local Growth = require("models.growth")
local Item = require("models.item")
local InputMode = require("input_mode")

local JobsEditor = {}
JobsEditor.__index = JobsEditor

local ROW_H = 30
local BUTTON_H = 34

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- The seven root classes, in a fixed order. Class.roots() is keyed by id and `pairs` over it is
-- unspecified, so a list that reordered itself between two openings of the same panel would read as a
-- bug -- and this is a screen the player learns the shape of.
local function classOrder()
    local out = {}
    for id in pairs(Class.roots()) do out[#out + 1] = id end
    table.sort(out)
    return out
end

-- Every crossing that names `class` as one of its two parents.
local function crossingsOf(class)
    local out = {}
    for id, def in pairs(Class.defs) do
        if Class.arity(id) == 2 then
            for _, p in ipairs(Class.parents(id)) do
                if p == class then out[#out + 1] = id end
            end
        end
    end
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------------------
-- The rows
-- ---------------------------------------------------------------------------

-- Every job this body may stand in, flattened into drawable rows: a header per base class, the class
-- itself, then whichever of its subclasses and crossings this body has opened.
--
-- Built fresh per body rather than once per panel, because every number on a row -- level, progress --
-- is a question about ONE character, and a cached list would answer it about whoever was on the rail
-- when the tab was first opened.
function JobsEditor:buildRows()
    self.rows = {}
    local char = self.char

    local function job(id, kind, parent)
        local held, needed, level = 0, 0, 0
        if char then held, needed, level = Class.classProgress(char, id) end
        self.rows[#self.rows + 1] = {
            id = id, kind = kind, parent = parent,
            name = kind == "class" and Item.classDisplayName(id) or Class.displayName(id),
            level = level, held = held, needed = needed,
        }
    end

    for _, class in ipairs(classOrder()) do
        self.rows[#self.rows + 1] = { header = true, name = Item.classDisplayName(class), id = class }
        -- A base class is never gated: everyone may be a knight.
        job(class, "class")

        local hidden = 0
        local subs = Class.subclassesOf(class)
        table.sort(subs)
        for _, id in ipairs(subs) do
            if char and Class.isUnlocked(char, id) then
                job(id, "subclass", class)
            else
                hidden = hidden + 1
            end
        end
        for _, id in ipairs(crossingsOf(class)) do
            if char and Class.isUnlocked(char, id) then
                job(id, "multiclass", class)
            else
                hidden = hidden + 1
            end
        end

        -- WHAT IS STILL BEHIND THIS CLASS, counted and not named. Without it a fresh body's roll is
        -- seven rows and reads as the whole game; with the names it is the greyed-out wall this screen
        -- exists not to be.
        if hidden > 0 then
            self.rows[#self.rows + 1] = {
                hint = true,
                name = hidden == 1 and "1 more path opens further along this class"
                    or (hidden .. " more paths open further along this class"),
            }
        end
    end

    if not self:isSelectable(self.cursor) then
        self.cursor = 0
        self:step(1)
    end
    self:scrollToCursor()
end

function JobsEditor:isSelectable(i)
    local row = i and self.rows[i]
    return row ~= nil and not row.header and not row.hint
end

function JobsEditor:currentRow()
    local row = self.rows[self.cursor]
    if row and (row.header or row.hint) then return nil end
    return row
end

-- Move the cursor by `dir`, skipping the rows that are only there to be read. Stops at the ends rather
-- than wrapping: this list runs deep and a wrap from the bottom to the top reads as the cursor lost.
function JobsEditor:step(dir)
    local i = self.cursor or 0
    for _ = 1, #self.rows do
        i = i + dir
        if i < 1 then i = 1 end
        if i > #self.rows then i = #self.rows end
        if self:isSelectable(i) then
            self.cursor = i
            self:scrollToCursor()
            return
        end
        if (dir < 0 and i == 1) or (dir > 0 and i == #self.rows) then break end
    end
end

function JobsEditor:visibleRows()
    return math.max(1, math.floor((self.h - 30) / ROW_H))
end

function JobsEditor:scrollToCursor()
    local span = self:visibleRows()
    self.scroll = self.scroll or 0
    -- A header is drawn above its first job, so a cursor on that job scrolls one extra row to keep the
    -- name of the class it belongs to on screen with it.
    local target = self.cursor
    if self.rows[target - 1] and self.rows[target - 1].header then target = target - 1 end
    if target < self.scroll + 1 then self.scroll = target - 1 end
    if self.cursor > self.scroll + span then self.scroll = self.cursor - span end
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, #self.rows - span)))
end

-- ---------------------------------------------------------------------------

function JobsEditor.new(opts)
    local self = setmetatable({}, JobsEditor)
    self.x, self.y, self.w, self.h = opts.x, opts.y, opts.w, opts.h
    self.fonts = opts.fonts

    -- Split: the job list on the left, the highlighted job in full on the right. The same proportion
    -- the rule editor next door uses, so a tab change does not re-cut the column.
    self.listX = self.x
    self.listW = math.floor(self.w * 0.56)
    self.detailX = self.listX + self.listW + 20
    self.detailW = self.w - self.listW - 20
    self.listY = self.y + 24

    self.cursor = 1
    self.scroll = 0
    self.rows = {}
    self.rowRects = {}

    self:setChar(opts.char)
    return self
end

function JobsEditor:setChar(char)
    self.char = char
    self.cursor = 1
    self.scroll = 0
    self.hoverRow, self.hoverDeclare = nil, nil
    self:buildRows()
end

-- ---------------------------------------------------------------------------
-- Declaring
-- ---------------------------------------------------------------------------

-- Can this body take the highlighted job as its own? Every row on the list is one it has already
-- opened (a locked job is not drawn), so the only refusal left is the job it is already standing in.
function JobsEditor:canDeclare()
    local row = self:currentRow()
    if not (row and self.char) then return false end
    return row.id ~= Growth.jobOf(self.char)
end

function JobsEditor:declare()
    if not self:canDeclare() then return false end
    self.char.job = self:currentRow().id
    return true
end

-- ---------------------------------------------------------------------------
-- Column-editor contract (see Party:columnEditor)
-- ---------------------------------------------------------------------------

-- One region, so Tab has nothing of its own to walk: the host is told the walk is over on the first
-- press and takes the focus back out to the rail.
function JobsEditor:cycleRegion()
    return false
end

function JobsEditor:isFirstRegion()
    return true
end

function JobsEditor:navigate(dc, dr)
    -- Left/right has nothing to change on a row: the list is the only axis here, and crossing left back
    -- to the rail is the host's business (Party:navigate reads isFirstRegion).
    local _ = dc
    if dr ~= 0 then self:step(dr) end
end

function JobsEditor:confirm()
    self:declare()
end

function JobsEditor:cancel()
    return false -- nothing here is held open, so Esc belongs to the panel
end

function JobsEditor:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function JobsEditor:mousemoved(x, y)
    self.hoverRow = nil
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) then self.hoverRow = i break end
    end
    self.hoverDeclare = hit(self.declareRect, x, y)
end

function JobsEditor:wheelmoved(dy)
    local span = self:visibleRows()
    self.scroll = math.max(0, math.min(self.scroll - dy, math.max(0, #self.rows - span)))
end

function JobsEditor:mousepressed(x, y)
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) and self:isSelectable(i) then
            self.cursor = i
            return true
        end
    end
    if hit(self.declareRect, x, y) then
        self:declare()
        return true
    end
    return false
end

function JobsEditor:cursorKind(x, y)
    if hit(self.declareRect, x, y) then return "hand" end
    for i, r in pairs(self.rowRects) do
        if hit(r, x, y) and self:isSelectable(i) then return "hand" end
    end
    return "arrow"
end

function JobsEditor:prompts()
    local pad = InputMode.isGamepad()
    local out = {}
    local function add(glyph, label) out[#out + 1] = { glyph = glyph, label = label } end
    add(pad and "D-pad" or "Up/Down", "Pick job")
    -- The one verb, offered only where it is legal: a body already standing in the highlighted job has
    -- nothing to press, and a prompt for it would read as the press having failed.
    if self:canDeclare() then add(pad and "A" or "Enter", "Declare") end
    return out
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

local function levelColor(level)
    if level >= Class.CLASS_LEVEL_CAP then return Theme.accentAmber end
    if level > 0 then return Theme.ink end
    return Theme.muted
end

function JobsEditor:drawList(focused)
    local x, y, w = self.listX, self.listY, self.listW
    local small, body = self.fonts.small, self.fonts.body

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    love.graphics.print("JOBS", x, self.y)
    love.graphics.printf("LEVEL", x, self.y, w, "right")

    local span = self:visibleRows()
    self.rowRects = {}

    for i = self.scroll + 1, math.min(#self.rows, self.scroll + span) do
        local row = self.rows[i]
        local ry = y + (i - self.scroll - 1) * ROW_H
        self.rowRects[i] = { x = x, y = ry, w = w, h = ROW_H - 2 }

        if row.header then
            Theme.set(Theme.frame)
            love.graphics.line(x, ry + ROW_H - 6, x + w, ry + ROW_H - 6)
            love.graphics.setFont(small)
            Theme.set(Theme.muted)
            Theme.printTracked(string.upper(row.name), x, ry + 4, w, 1)
        elseif row.hint then
            love.graphics.setFont(small)
            Theme.set(Theme.muted, 0.6)
            love.graphics.print(row.name, x + 24, ry + 6)
        else
            local on = i == self.cursor
            if on then
                Theme.plate(x, ry, w, ROW_H - 2, 3, Theme.panel)
                Theme.set(focused and Theme.cursor or Theme.frame)
                love.graphics.rectangle("line", x, ry, w, ROW_H - 2, 3, 3)
            end

            -- A crossing is indented one step further than a subclass, so the shape of the tree is in
            -- the margin even though the rows are a list.
            local indent = row.kind == "class" and 10
                or row.kind == "subclass" and 24 or 38
            Theme.set(levelColor(row.level))
            local font, name = Theme.fitText(Theme.body, row.name, w - indent - 90, 15, 12)
            love.graphics.setFont(font)
            love.graphics.print(name, x + indent, ry + 5)

            if self.char and Growth.jobOf(self.char) == row.id then
                Theme.set(Theme.accentAmber)
                love.graphics.setFont(body)
                love.graphics.print("*", x + 2, ry + 5)
            end

            love.graphics.setFont(small)
            Theme.set(levelColor(row.level))
            love.graphics.printf(tostring(row.level), x, ry + 6, w - 10, "right")
            -- The bar is the rung, not the career: how far into the level it is standing on. At the cap
            -- there is no span left, so it draws full rather than empty.
            local frac = row.needed > 0 and (row.held / row.needed) or 1
            ProgressBar.draw(x + w - 74, ry + 11, 44, 5, frac, 1,
                { color = row.level >= Class.CLASS_LEVEL_CAP and Theme.accentAmber or Theme.cursor })
        end
    end

    if #self.rows > span then
        love.graphics.setFont(small)
        Theme.set(Theme.muted, 0.5)
        love.graphics.printf(string.format("%d / %d", math.min(#self.rows, self.scroll + span), #self.rows),
            x, y + span * ROW_H + 4, w, "right")
    end
end

function JobsEditor:drawDetail()
    local x, y, w = self.detailX, self.y, self.detailW
    local row, char = self:currentRow(), self.char
    self.declareRect = nil
    if not row then return end
    local small, body = self.fonts.small, self.fonts.body

    local font, name = Theme.fitText(Theme.display, row.name, w, 18, 13)
    love.graphics.setFont(font)
    Theme.set(Theme.ink)
    love.graphics.print(name, x, y)

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    local kindLabel = row.kind == "class" and "Base class"
        or row.kind == "subclass" and ("Subclass of " .. Item.classDisplayName(row.parent))
        or "Crossing"
    love.graphics.print(kindLabel, x, y + 26)

    local ty = y + 50

    -- What the path IS. A job collapses to a name and a number everywhere else in the game; this is the
    -- one screen with room to say why anyone would want it.
    local blurb = row.kind ~= "class" and Class.description(row.id) or Item.classDescription(row.id)
    if type(blurb) == "string" then
        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        love.graphics.printf(blurb, x, ty, w, "left")
        local _, lines = small:getWrap(blurb, w)
        ty = ty + small:getHeight() * math.max(1, #lines) + 14
    end

    -- This body's standing on it, as a transition rather than a bare figure: what the next rung costs
    -- is the number a player is actually deciding against.
    if char then
        Theme.set(Theme.frame)
        love.graphics.line(x, ty, x + w, ty)
        ty = ty + 12

        love.graphics.setFont(body)
        Theme.set(Theme.ink)
        love.graphics.print((char.name or "?") .. ": " .. row.name .. " " .. tostring(row.level), x, ty)
        ty = ty + 22

        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        if row.level >= Class.CLASS_LEVEL_CAP then
            love.graphics.print("Mastered.", x, ty)
        else
            love.graphics.print(string.format("%d / %d to %d", row.held, row.needed, row.level + 1), x, ty)
            ProgressBar.draw(x, ty + 18, w, 6, row.needed > 0 and row.held / row.needed or 0, 1,
                { color = Theme.cursor })
        end
        ty = ty + 40

        if Growth.jobOf(char) == row.id then
            Theme.set(Theme.accentAmber)
            love.graphics.print("Declared. Growth follows this job.", x, ty)
        end
    end

    -- THE ONE ACT ON THIS TAB, and it draws only where it is legal: a body already declared in this job
    -- has nothing to press. A greyed plate would be a control that is never pressable pretending to be
    -- one that is.
    if self:canDeclare() then
        local by = self.y + self.h - BUTTON_H - 22
        self.declareRect = { x = x, y = by, w = w, h = BUTTON_H }
        Theme.plate(x, by, w, BUTTON_H, 4, self.hoverDeclare and Theme.panel or Theme.panel2)
        Theme.set(Theme.accentAmber)
        love.graphics.rectangle("line", x, by, w, BUTTON_H, 4, 4)
        love.graphics.setFont(body)
        love.graphics.printf("Declare " .. row.name, x, by + 9, w, "center")

        love.graphics.setFont(small)
        Theme.set(Theme.muted)
        love.graphics.printf("Levels already earned keep what they grew.", x, by + BUTTON_H + 4, w, "center")
    end
end

function JobsEditor:draw(focused)
    self:drawList(focused ~= false)
    self:drawDetail()
    love.graphics.setColor(1, 1, 1)
end

return JobsEditor
