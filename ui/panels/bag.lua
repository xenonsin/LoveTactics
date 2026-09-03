-- THE BAG: a second container, opened from the grid cell that holds it.
--
-- The 3x3 grid is the whole of what a body can reach, and nothing here widens it. A bag holds what the
-- grid had no cell for, and what keeps it a design rather than extra pockets is where its contents come
-- from: the Thief's is fed by THEFT alone (models/combat.lua's Combat.steal), so everything in it was
-- taken off somebody during this fight. You cannot shop into it.
--
-- It exists because a lift had nowhere to go. Combat.steal tries the thief's grid, then dropped to the
-- party stash -- and the stash is out of the battle, so on a nine-cell grid already carrying a build,
-- "steal it" mostly meant "remove it from play". Fine for a denial tool, poor for a signature whose
-- whole payoff is USING what you took.
--
-- Taking one OUT is the panel's single verb, and it is reversible in the only sense that matters: the
-- thing is yours either way, this decides whether it is in your hand this turn. So a click commits
-- directly rather than needing a second confirm the way the reliquary's irreversible take does.
--
-- Same panel contract as the rest of ui/panels/: a state owns it and forwards input while it is open;
-- three-input (mouse + keyboard + gamepad) with a clickable X for a mouse-only player.
--
--   local panel = Bag.new({
--       bag     = item,                       -- the bag item itself (Item.bagRoom / .contents)
--       onTake  = function(held) ... end,      -- move `held` out; return false if there was no room
--       onClose = function() ... end,
--   })

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Item = require("models.item")
local Scale = require("scale")
local Theme = require("ui.theme")

local Bag = {}
Bag.__index = Bag

local PAD = 30
local COLS = 3
local CELL_W, CELL_H, CELL_GAP = 190, 74, 12

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function Bag.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Bag)
    self.bag = opts.bag
    self.onTake = opts.onTake
    self.onClose = opts.onClose
    self.focus = 1
    self.notice = nil

    self.titleFont = Theme.display(26)
    self.promptFont = Theme.body(15)
    self.bodyFont = Theme.body(14)
    self.hintFont = Theme.body(14)

    -- The box is sized for the bag's CAPACITY, not for what is in it, so it does not resize as things
    -- are taken out from under the cursor. An empty slot is drawn as an empty slot -- which is also
    -- the readout for how much more she can lift before the stash starts eating it again.
    local cap = math.max(1, (self.bag and self.bag.bag and self.bag.bag.capacity) or 1)
    self.rows = math.ceil(cap / COLS)
    self.cap = cap

    self.boxW = PAD * 2 + COLS * CELL_W + (COLS - 1) * CELL_GAP
    self.oPrompt = 56
    self.oCells = self.oPrompt + self.promptFont:getHeight() + 16
    self.oHint = self.oCells + self.rows * CELL_H + (self.rows - 1) * CELL_GAP + 18
    self.boxH = self.oHint + self.hintFont:getHeight() + PAD - 6
    self.boxX = Scale.WIDTH / 2 - self.boxW / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2

    self.cells = {}
    for i = 1, cap do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        self.cells[i] = {
            x = self.boxX + PAD + col * (CELL_W + CELL_GAP),
            y = self.boxY + self.oCells + row * (CELL_H + CELL_GAP),
            w = CELL_W, h = CELL_H,
        }
    end

    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)
    return self
end

function Bag:held(i)
    return self.bag and self.bag.contents and self.bag.contents[i]
end

function Bag:count()
    return #((self.bag and self.bag.contents) or {})
end

-- Take the focused thing out. A refusal is reported rather than swallowed: "the grid is full" is the
-- one thing a player pressing this needs told, and it is fixable from the same screen by putting
-- something else away first.
function Bag:take(i)
    local held = self:held(i or self.focus)
    if not held then return end
    if self.onTake and self.onTake(held) == false then
        self.notice = "No room in the grid for the " .. (held.name or "item") .. "."
        return
    end
    Item.bagTake(self.bag, held)
    self.notice = (held.name or "It") .. " comes out."
    -- Taking the last thing in a row leaves the cursor past the end; walk it back to what is there.
    if self.focus > math.max(1, self:count()) then self.focus = math.max(1, self:count()) end
end

function Bag:close()
    if self.onClose then self.onClose() end
end

-- ---- drawing ----------------------------------------------------------------

function Bag:drawCell(i, focused)
    local r = self.cells[i]
    local held = self:held(i)

    love.graphics.setColor(0.07, 0.075, 0.085, held and 0.95 or 0.55)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    local a = Theme.frame
    if focused then a = Theme.accentAmber end
    love.graphics.setColor(a[1], a[2], a[3], focused and 1 or (held and 0.7 or 0.3))
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setLineWidth(1)

    if not held then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.45, 0.44, 0.42, 0.7)
        love.graphics.printf("empty", r.x, r.y + r.h / 2 - self.bodyFont:getHeight() / 2, r.w, "center")
        return
    end

    -- The name never scales, and every cell prints at the SAME size -- a step-down would size each
    -- name against its own length, which reads as a ragged grid. A name too long for the cell
    -- ellipsizes instead.
    local font = Theme.display(17)
    local label = Theme.ellipsize(held.name or held.id or "Item", font, r.w - 20)
    love.graphics.setFont(font)
    love.graphics.setColor(0.94, 0.93, 0.89)
    love.graphics.printf(label, r.x + 10, r.y + 12, r.w - 20, "center")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.66, 0.61, 0.50)
    love.graphics.printf(held.type or "", r.x + 10, r.y + r.h - self.bodyFont:getHeight() - 10,
        r.w - 20, "center")
end

function Bag:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.bag and self.bag.name or "Bag", bx, by + 18, self.boxW, "center")

    love.graphics.setFont(self.promptFont)
    love.graphics.setColor(0.66, 0.61, 0.50)
    local line = self.notice
        or (self:count() == 0 and "Nothing in it yet. It fills with what you take off people."
            or string.format("%d of %d. Take one out to put it in your hand.", self:count(), self.cap))
    love.graphics.printf(line, bx + PAD, by + self.oPrompt, self.boxW - PAD * 2, "center")

    for i = 1, self.cap do self:drawCell(i, i == self.focus) end

    local hint = InputMode.isGamepad() and "D-pad choose  -  A take out  -  B close"
        or "Arrows choose  -  Enter take out  -  Esc close"
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, bx, by + self.oHint, self.boxW, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function Bag:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    for i = 1, self.cap do
        if inRect(self.cells[i], x, y) then self.focus = i; break end
    end
end

function Bag:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for i = 1, self.cap do
        if inRect(self.cells[i], x, y) and self:held(i) then return "hand" end
    end
    return "arrow"
end

-- A click commits. Unlike the reliquary's take, this is not a road you cannot walk back: the thing is
-- hers either way, and this only decides whether it is in her hand this turn.
function Bag:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close(); return end
    for i = 1, self.cap do
        if inRect(self.cells[i], x, y) then
            self.focus = i
            if self:held(i) then self:take(i) end
            return
        end
    end
end

function Bag:moveFocus(dx, dy)
    local i = self.focus - 1
    local col, row = i % COLS, math.floor(i / COLS)
    col = (col + dx) % COLS
    row = (row + dy) % self.rows
    self.focus = math.min(self.cap, row * COLS + col + 1)
end

function Bag:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "left" or key == "a" then self:moveFocus(-1, 0)
    elseif key == "right" or key == "d" then self:moveFocus(1, 0)
    elseif key == "up" or key == "w" then self:moveFocus(0, -1)
    elseif key == "down" or key == "s" then self:moveFocus(0, 1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:take() end
end

function Bag:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpleft" then self:moveFocus(-1, 0)
    elseif button == "dpright" then self:moveFocus(1, 0)
    elseif button == "dpup" then self:moveFocus(0, -1)
    elseif button == "dpdown" then self:moveFocus(0, 1)
    elseif button == "a" or button == "start" then self:take() end
end

return Bag
