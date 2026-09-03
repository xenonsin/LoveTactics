-- THE ROLL: what each body in the company IS, and every job it could become.
--
-- The screen the class system was missing. A body carries a declared job that decides how it grows
-- (Growth.jobOf) and a level in every class it has ever swung (Discipline.classLevel), and until this
-- panel existed neither was drawn anywhere -- the ledger was written every fight, persisted through
-- every save, and shown to nobody. A number the player cannot see is a number they cannot play toward.
--
-- THREE COLUMNS, and each answers one question:
--
--   WHO    the roster, one row a body, with the job it is declared in under its name.
--   WHAT   every job, grouped under the class it hangs off: this body's level, how far into the next
--          rung it is, and whether it is open at all.
--   WHY    the highlighted job in full -- what the path is, what it wants, and what stands in the way.
--
-- IT IS A LIST, NOT A LATTICE, and that is a decision rather than a shortcut. Forty-five jobs across
-- seven parents with twenty-one crossings between them is a real graph, and drawn as one at 1280x720 it
-- is a plate of spaghetti nobody can read a number off. FFT's own job screen is a list too, for the same
-- reason: what a player actually does here is compare a job's level against its gate, and a list puts
-- those two numbers on one line. The lattice is still true -- it is just stated in words, in the detail
-- column, where a crossing can say WHICH two parents it wants and how far off each is.
--
-- A MULTICLASS IS FILED UNDER BOTH ITS PARENTS. Shopping both shelves is literally how you build one
-- (models/vendor.lua says the same about its stock), so hiding it under one parent would make half the
-- crossings invisible to a player reading down the other.
--
-- DECLARING A JOB IS THE ONE ACT ON THIS SCREEN, and it is free and reversible. `growthBy` is gone and
-- nothing is re-apportioned when you switch (models/growth.lua) -- levels already credited are never
-- revisited -- so changing your mind costs the levels ahead of you, never the ones behind. That is what
-- makes a job a decision the player can afford to make early.
--
-- Mouse, keyboard and pad, like every panel here: the columns are one focus chain, Left/Right moves
-- between them, Up/Down inside one, and the mouse may land anywhere at any time.

local Theme = require("ui.theme")
local Scale = require("scale")
local CloseButton = require("ui.close_button")
local ProgressBar = require("ui.progress_bar")
local Discipline = require("models.discipline")
local Growth = require("models.growth")
local Item = require("models.item")
local InputMode = require("input_mode")

local Jobs = {}
Jobs.__index = Jobs

local BOX_W, BOX_H = 1060, 600
local ROSTER_W = 230
local DETAIL_W = 300
local ROW_H = 30
local ROSTER_ROW_H = 46

-- The seven base classes, in a fixed order. `Item.CLASSES` is keyed by id and `pairs` over it is
-- unspecified, so a list that reordered itself between two openings of the same panel would read as a
-- bug -- and this is a screen the player learns the shape of.
local function classOrder()
    local out = {}
    for id in pairs(Item.CLASSES) do out[#out + 1] = id end
    table.sort(out)
    return out
end

local function pointIn(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- ---------------------------------------------------------------------------
-- The rows
-- ---------------------------------------------------------------------------

-- Every job, flattened into drawable rows: a header per base class, then that class itself, then its
-- subclasses, then the crossings that name it as a parent.
--
-- Built fresh per body rather than once per panel, because every number on a row -- level, progress,
-- locked -- is a question about ONE character, and a cached list would answer it about whoever was
-- selected when the panel opened.
function Jobs:buildRows()
    self.rows = {}
    local char = self:selected()

    local function job(id, kind, parent)
        local level, held, needed = 0, 0, 0
        if char then
            held, needed, level = Discipline.classProgress(char, id)
        end
        local locked = false
        if kind ~= "class" and char then
            locked = not Discipline.isUnlocked(char, id)
        end
        self.rows[#self.rows + 1] = {
            id = id, kind = kind, parent = parent,
            name = kind == "class" and Item.classDisplayName(id) or Discipline.displayName(id),
            level = level, held = held, needed = needed, locked = locked,
        }
    end

    for _, class in ipairs(classOrder()) do
        self.rows[#self.rows + 1] = { header = true, name = Item.classDisplayName(class), id = class }
        job(class, "class")

        local subs = Discipline.subclassesOf(class)
        table.sort(subs)
        for _, id in ipairs(subs) do job(id, "subclass", class) end

        -- The crossings that name this class as one of their two parents, so a multiclass appears under
        -- both halves of what it is made of.
        local crossings = {}
        for id, def in pairs(Discipline.defs) do
            if #(def.classes or {}) == 2 then
                for _, p in ipairs(def.classes) do
                    if p == class then crossings[#crossings + 1] = id end
                end
            end
        end
        table.sort(crossings)
        for _, id in ipairs(crossings) do job(id, "multiclass", class) end
    end

    -- Keep the cursor on something selectable after a rebuild: a header is drawn but never landed on.
    if not self.rows[self.jobIndex] or self.rows[self.jobIndex].header then
        self:stepJob(1)
    end
end

function Jobs:selected()
    return self.roster and self.roster[self.charIndex]
end

function Jobs:currentRow()
    return self.rows and self.rows[self.jobIndex]
end

-- Move the job cursor by `dir`, skipping headers. Stops at the ends rather than wrapping: this list is
-- forty-five rows deep and a wrap from the bottom to the top reads as the cursor being lost.
function Jobs:stepJob(dir)
    local i = self.jobIndex or 0
    for _ = 1, #self.rows do
        i = i + dir
        if i < 1 then i = 1 end
        if i > #self.rows then i = #self.rows end
        if self.rows[i] and not self.rows[i].header then
            self.jobIndex = i
            self:scrollToCursor()
            return
        end
        if (dir < 0 and i == 1) or (dir > 0 and i == #self.rows) then break end
    end
end

function Jobs:visibleRows()
    return math.floor((BOX_H - 150) / ROW_H)
end

function Jobs:scrollToCursor()
    local span = self:visibleRows()
    self.scroll = self.scroll or 0
    -- A header is drawn above its first job, so a cursor on that job scrolls one extra row to keep the
    -- name of the class it belongs to on screen with it.
    local target = self.jobIndex
    if self.rows[target - 1] and self.rows[target - 1].header then target = target - 1 end
    if target < self.scroll + 1 then self.scroll = target - 1 end
    if self.jobIndex > self.scroll + span then self.scroll = self.jobIndex - span end
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, #self.rows - span)))
end

-- ---------------------------------------------------------------------------

function Jobs.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Jobs)
    self.onClose = opts.onClose
    self.player = opts.player
    self.title = opts.title or "The Roll"

    self.roster = {}
    for _, c in ipairs((self.player and self.player.roster) or {}) do self.roster[#self.roster + 1] = c end

    self.charIndex = 1
    self.jobIndex = 1
    self.scroll = 0
    self.focus = "jobs" -- "roster" | "jobs"

    self.titleFont = Theme.display(26)
    self.headFont = Theme.display(17)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.rosterX = self.boxX + 20
    self.listX = self.rosterX + ROSTER_W + 18
    self.listW = BOX_W - ROSTER_W - DETAIL_W - 76
    self.detailX = self.listX + self.listW + 18
    self.listY = self.boxY + 96

    self:buildRows()
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function Jobs:close()
    if self.onClose then self.onClose() end
end

-- ---------------------------------------------------------------------------
-- Declaring
-- ---------------------------------------------------------------------------

-- Can this body take the highlighted job as its own? A class is always available -- everyone may be a
-- knight -- and a discipline wants its gate met BY THIS BODY (Discipline.isUnlocked), which is the whole
-- of the per-unit rule.
function Jobs:canDeclare()
    local row, char = self:currentRow(), self:selected()
    if not (row and char) or row.header then return false end
    if row.id == Growth.jobOf(char) then return false end
    return not row.locked
end

function Jobs:declare()
    if not self:canDeclare() then return false end
    local char, row = self:selected(), self:currentRow()
    char.job = row.id
    return true
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Jobs:keypressed(key)
    if key == "escape" then self:close(); return end

    if key == "left" then
        self.focus = "roster"
    elseif key == "right" then
        self.focus = "jobs"
    elseif key == "up" or key == "down" then
        local dir = key == "down" and 1 or -1
        if self.focus == "roster" then
            local n = #self.roster
            if n > 0 then
                self.charIndex = math.max(1, math.min(n, self.charIndex + dir))
                self:buildRows()
            end
        else
            self:stepJob(dir)
        end
    elseif key == "return" or key == "space" then
        self:declare()
    end
end

function Jobs:gamepadpressed(_, button)
    if button == "b" then self:close(); return end
    local map = {
        dpup = "up", dpdown = "down", dpleft = "left", dpright = "right", a = "return",
    }
    if map[button] then self:keypressed(map[button]) end
end

function Jobs:mousemoved(x, y)
    if self.closeButton then self.closeButton:mousemoved(x, y) end
    self.hoverDeclare = pointIn(self.declareRect, x, y)
end

function Jobs:wheelmoved(_, dy)
    local span = self:visibleRows()
    self.scroll = math.max(0, math.min(self.scroll - dy, math.max(0, #self.rows - span)))
end

function Jobs:mousepressed(x, y, button)
    if self.closeButton and self.closeButton:mousepressed(x, y, button) then self:close(); return end
    if button ~= 1 then return end

    for i, r in ipairs(self.rosterRects or {}) do
        if pointIn(r, x, y) then
            self.charIndex = i
            self.focus = "roster"
            self:buildRows()
            return
        end
    end

    for i, r in ipairs(self.rowRects or {}) do
        if pointIn(r, x, y) then
            self.jobIndex = i
            self.focus = "jobs"
            return
        end
    end

    if pointIn(self.declareRect, x, y) then self:declare() end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

local function levelColor(level, locked)
    if locked then return Theme.muted end
    if level >= Discipline.CLASS_LEVEL_CAP then return Theme.accentAmber end
    if level > 0 then return Theme.ink end
    return Theme.muted
end

function Jobs:drawRoster()
    local x, y = self.rosterX, self.listY
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.print("COMPANY", x, y - 22)

    self.rosterRects = {}
    for i, char in ipairs(self.roster) do
        local ry = y + (i - 1) * ROSTER_ROW_H
        local rect = { x = x, y = ry, w = ROSTER_W, h = ROSTER_ROW_H - 4 }
        self.rosterRects[i] = rect

        local on = i == self.charIndex
        Theme.plate(rect.x, rect.y, rect.w, rect.h, 4, on and Theme.panel or Theme.panel2)
        if on then
            Theme.set(self.focus == "roster" and Theme.cursor or Theme.frame)
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 4, 4)
        end

        love.graphics.setFont(self.bodyFont)
        Theme.set(on and Theme.ink or Theme.muted)
        local font, name = Theme.fitText(Theme.body, char.name or "?", ROSTER_W - 20, 15, 12)
        love.graphics.setFont(font)
        love.graphics.print(name, rect.x + 10, rect.y + 5)

        -- The declared job under the name, which is the one thing about a body this screen exists to
        -- state. Amber because it is what the player set, and the same amber the mastered rung wears.
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.accentAmber)
        love.graphics.print("Lv " .. tostring(char.level or 1) .. "  " ..
            (Discipline.displayName(Growth.jobOf(char)) or Item.classDisplayName(Growth.jobOf(char)) or "?"),
            rect.x + 10, rect.y + 24)
    end
end

function Jobs:drawList()
    local x, y, w = self.listX, self.listY, self.listW
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.print("JOBS", x, y - 22)
    Theme.set(Theme.muted)
    love.graphics.printf("LEVEL", x, y - 22, w, "right")

    local span = self:visibleRows()
    local char = self:selected()
    self.rowRects = {}

    for i = self.scroll + 1, math.min(#self.rows, self.scroll + span) do
        local row = self.rows[i]
        local ry = y + (i - self.scroll - 1) * ROW_H
        self.rowRects[i] = { x = x, y = ry, w = w, h = ROW_H - 2 }

        if row.header then
            Theme.set(Theme.frame)
            love.graphics.line(x, ry + ROW_H - 6, x + w, ry + ROW_H - 6)
            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.muted)
            Theme.printTracked(string.upper(row.name), x, ry + 4, w, 1)
        else
            local on = i == self.jobIndex
            if on then
                Theme.plate(x, ry, w, ROW_H - 2, 3, Theme.panel)
                Theme.set(self.focus == "jobs" and Theme.cursor or Theme.frame)
                love.graphics.rectangle("line", x, ry, w, ROW_H - 2, 3, 3)
            end

            -- A crossing is indented one step further than a subclass, so the shape of the tree is in
            -- the margin even though the rows are a list.
            local indent = row.kind == "class" and 10
                or row.kind == "subclass" and 24 or 38
            love.graphics.setFont(self.bodyFont)
            Theme.set(levelColor(row.level, row.locked))
            local font, name = Theme.fitText(Theme.body, row.name, w - indent - 90, 15, 12)
            love.graphics.setFont(font)
            love.graphics.print(name, x + indent, ry + 5)

            if char and Growth.jobOf(char) == row.id then
                Theme.set(Theme.accentAmber)
                love.graphics.print("*", x + 2, ry + 5)
            end

            love.graphics.setFont(self.smallFont)
            if row.locked then
                Theme.set(Theme.muted)
                love.graphics.printf("locked", x, ry + 7, w - 10, "right")
            else
                Theme.set(levelColor(row.level, false))
                love.graphics.printf(tostring(row.level), x, ry + 6, w - 10, "right")
                -- The bar is the rung, not the career: how far into the level it is standing on. At the
                -- cap there is no span left, so it draws full rather than empty.
                local frac = row.needed > 0 and (row.held / row.needed) or 1
                ProgressBar.draw(x + w - 74, ry + 11, 44, 5, frac, 1,
                    { color = row.level >= Discipline.CLASS_LEVEL_CAP and Theme.accentAmber or Theme.cursor })
            end
        end
    end

    if #self.rows > span then
        Theme.set(Theme.muted, 0.5)
        love.graphics.printf(string.format("%d / %d", math.min(#self.rows, self.scroll + span), #self.rows),
            x, y + span * ROW_H + 6, w, "right")
    end
end

function Jobs:drawDetail()
    local x, y, w = self.detailX, self.listY, DETAIL_W
    local row, char = self:currentRow(), self:selected()
    self.declareRect = nil
    if not row or row.header then return end

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.ink)
    local font, name = Theme.fitText(Theme.display, row.name, w, 17, 13)
    love.graphics.setFont(font)
    love.graphics.print(name, x, y)

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local kindLabel = row.kind == "class" and "Base class"
        or row.kind == "subclass" and ("Subclass of " .. Item.classDisplayName(row.parent))
        or "Crossing"
    love.graphics.print(kindLabel, x, y + 26)

    local ty = y + 52

    -- What the path IS. A locked row collapses to a name and a gate everywhere else in the game; this
    -- is the one screen with room to say why anyone would want it.
    local blurb = row.kind ~= "class" and Discipline.description(row.id) or Item.CLASSES[row.id]
    if blurb then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted)
        love.graphics.printf(blurb, x, ty, w, "left")
        ty = ty + self.smallFont:getHeight() * (1 + math.floor(self.smallFont:getWidth(blurb) / w)) + 14
    end

    -- This body's standing on it, as a transition rather than a bare figure: what the next rung costs
    -- is the number a player is actually deciding against.
    if char then
        Theme.set(Theme.frame)
        love.graphics.line(x, ty, x + w, ty)
        ty = ty + 12

        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.ink)
        love.graphics.print((char.name or "?") .. ": " .. row.name .. " " .. tostring(row.level), x, ty)
        ty = ty + 22

        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted)
        if row.level >= Discipline.CLASS_LEVEL_CAP then
            love.graphics.print("Mastered.", x, ty)
        else
            love.graphics.print(string.format("%d / %d to %d", row.held, row.needed, row.level + 1), x, ty)
            ProgressBar.draw(x, ty + 18, w, 6, row.needed > 0 and row.held / row.needed or 0, 1,
                { color = Theme.cursor })
        end
        ty = ty + 40
    end

    -- What stands in the way, in the unit the gate is written in. A crossing names both its parents,
    -- because "you need a rogue path" and "you need a mage path" are two different errands.
    local def = Discipline.defs[row.id]
    if row.locked and def then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.accentWeapon)
        love.graphics.print("Wants", x, ty)
        ty = ty + 18
        Theme.set(Theme.muted)
        for class, level in pairs(def.requiredLevel or {}) do
            local have = char and Discipline.classLevel(char, class) or 0
            love.graphics.print(string.format("%s %d  (you have %d)",
                Item.classDisplayName(class) or class, level, have), x + 8, ty)
            ty = ty + 16
        end
        if #(def.classes or {}) == 2 then
            for _, parent in ipairs(def.classes) do
                local held = false
                for _, sub in ipairs(Discipline.subclassesOf(parent)) do
                    if char and Discipline.isUnlocked(char, sub) then held = true; break end
                end
                if not held then
                    -- The article agrees with the name it is in front of. Seven class names, one of
                    -- which starts with a vowel, so "a Alchemist path" is on screen a seventh of the
                    -- time this line is drawn at all -- often enough to read as a typo and rare enough
                    -- to survive a quick look.
                    local label = Item.classDisplayName(parent) or parent
                    local article = label:match("^[AEIOUaeiou]") and "an " or "a "
                    love.graphics.print(article .. label .. " path", x + 8, ty)
                    ty = ty + 16
                end
            end
        end
        ty = ty + 8
    end

    -- THE ONE ACT ON THIS SCREEN, and it draws only where it is legal: a body already declared in this
    -- job has nothing to press, and a locked row has nothing to offer. A greyed plate in either case
    -- would be a control that is never pressable pretending to be one that is.
    if self:canDeclare() then
        local bw, bh = w, 34
        local by = self.boxY + BOX_H - 70
        self.declareRect = { x = x, y = by, w = bw, h = bh }
        Theme.plate(x, by, bw, bh, 4, self.hoverDeclare and Theme.panel or Theme.panel2)
        Theme.set(Theme.accentAmber)
        love.graphics.rectangle("line", x, by, bw, bh, 4, 4)
        love.graphics.setFont(self.bodyFont)
        love.graphics.printf("Declare " .. row.name, x, by + 9, bw, "center")

        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted)
        love.graphics.printf("Growth follows the job. Levels already earned keep what they grew.",
            x, by + bh + 6, bw, "center")
    end
end

function Jobs:draw()
    Theme.plate(self.boxX, self.boxY, BOX_W, BOX_H, 8)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.ink)
    love.graphics.print(self.title, self.boxX + 24, self.boxY + 22)

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf(InputMode.isGamepad() and "A declare   B close" or "Enter declare   Esc close",
        self.boxX, self.boxY + 30, BOX_W - 56, "right")

    self:drawRoster()
    self:drawList()
    self:drawDetail()

    if self.closeButton then self.closeButton:draw() end
end

return Jobs
