-- THE MAW'S PANEL (models/maw.lua, data/encounters/encounter_the_maw.lua): the pack's feedable pieces in two
-- columns, ticked on and off, and one button that feeds it exactly the number it asks for. Three-input and
-- mouse-only, like every panel here; a state owns it as game.activePanel and forwards input.
--
--   MawPanel.new({ title=, price=, candidates={ { index=, item= }, ... }, onFeed=function(indices) end,
--                  onClose= })
--
-- THE BUTTON IS DRAWN AND REFUSED until the count is right, never hidden (ui/panels/choice.lua's rule for a
-- dead card): it carries the count it is waiting for, which is the one number the player is working to.
-- A pack with fewer pieces than the price still opens, so the price can be read, and says so on the button.

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Item = require("models.item")
local Scale = require("scale")
local Theme = require("ui.theme")

local MawPanel = {}
MawPanel.__index = MawPanel

local BOX_W = 720
local PAD = 26
local ROW_H = 26
local ROW_GAP = 4
local ROWS_PER_COL = 14
local COL_GAP = 20
local BUTTON_H = 44

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function MawPanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, MawPanel)
    self.title = opts.title or "The Maw"
    self.price = opts.price or 1
    self.candidates = opts.candidates or {}
    self.onFeed = opts.onFeed
    self.onClose = opts.onClose
    self.picked = {}
    self.count = 0
    self.finished = false
    self.focus = 1

    self.titleFont = Theme.display(28)
    self.promptFont = Theme.body(15)
    self.rowFont = Theme.body(15)
    self.buttonFont = Theme.display(19)
    self.hintFont = Theme.body(13)

    local rows = math.min(ROWS_PER_COL, math.max(1, #self.candidates))
    self.listTop = 86
    self.boxW = BOX_W
    self.boxH = self.listTop + rows * (ROW_H + ROW_GAP) + 18 + BUTTON_H + 40
    self.boxX = Scale.WIDTH / 2 - self.boxW / 2
    self.boxY = math.max(8, Scale.HEIGHT / 2 - self.boxH / 2)
    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)

    local colW = (BOX_W - PAD * 2 - COL_GAP) / 2
    for i, c in ipairs(self.candidates) do
        local col = math.floor((i - 1) / ROWS_PER_COL)
        local row = (i - 1) % ROWS_PER_COL
        c.rect = {
            x = self.boxX + PAD + col * (colW + COL_GAP),
            y = self.boxY + self.listTop + row * (ROW_H + ROW_GAP),
            w = colW, h = ROW_H,
        }
    end
    self.button = {
        x = self.boxX + BOX_W / 2 - 150, y = self.boxY + self.boxH - BUTTON_H - 34, w = 300, h = BUTTON_H,
    }
    return self
end

-- Focus runs over the rows and then the button, so the keyboard and the pad reach everything in one line.
function MawPanel:slots() return #self.candidates + 1 end
function MawPanel:ready() return self.count == self.price end

function MawPanel:toggle(i)
    local c = self.candidates[i]
    if not c or self.finished then return end
    if self.picked[i] then
        self.picked[i] = nil
        self.count = self.count - 1
    elseif self.count < self.price then
        self.picked[i] = true
        self.count = self.count + 1
    end
end

function MawPanel:feed()
    if self.finished or not self:ready() then return end
    local indices = {}
    for i, c in ipairs(self.candidates) do
        if self.picked[i] then indices[#indices + 1] = c.index end
    end
    self.finished = true
    if self.onFeed then self.onFeed(indices) end
end

function MawPanel:close()
    if self.finished or not self.onClose then return end
    self.finished = true
    self.onClose()
end

function MawPanel:activate(i)
    if i == self:slots() then self:feed() else self:toggle(i) end
end

function MawPanel:buttonLabel()
    if #self.candidates < self.price then
        return "Not enough pieces (" .. #self.candidates .. " / " .. self.price .. ")"
    end
    if self:ready() then return "Feed it" end
    return "Pick " .. self.price .. " (" .. self.count .. " / " .. self.price .. ")"
end

function MawPanel:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 16, self.boxW, "center")
    love.graphics.setFont(self.promptFont)
    love.graphics.setColor(0.82, 0.83, 0.88)
    local prompt = "It wants " .. self.price .. (self.price == 1 and " piece" or " pieces")
        .. ". They are destroyed. It gives back one sealed find a rank above the best of them."
    love.graphics.printf(prompt, bx + PAD, by + 52, self.boxW - PAD * 2, "center")

    if #self.candidates == 0 then
        love.graphics.setFont(self.rowFont)
        Theme.set(Theme.muted, 0.85)
        love.graphics.printf("Nothing in the pack can be fed to it.", bx, by + self.listTop + 4, self.boxW, "center")
    end
    for i, c in ipairs(self.candidates) do
        local r = c.rect
        local def = Item.defs[c.item.id] or {}
        local focused = (i == self.focus)
        local on = self.picked[i]
        love.graphics.setColor(0.12, 0.13, 0.16, focused and 0.95 or 0.6)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
        if on then
            Theme.set(Theme.accentAmber)
            love.graphics.rectangle("fill", r.x, r.y, 4, r.h, 2, 2)
        end
        love.graphics.setColor(0.62, 0.38, 0.72, focused and 1 or (on and 0.8 or 0.3))
        love.graphics.setLineWidth(focused and 2 or 1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
        love.graphics.setLineWidth(1)
        -- A tick box, filled when the piece is picked.
        local bs = 12
        local bxx, byy = r.x + 12, r.y + (r.h - bs) / 2
        love.graphics.setColor(0.86, 0.86, 0.90, 0.9)
        love.graphics.rectangle(on and "fill" or "line", bxx, byy, bs, bs, 2, 2)
        love.graphics.setFont(self.rowFont)
        local rank = "Rank " .. (def.unlockLevel or 0)
        local rankW = self.rowFont:getWidth(rank)
        love.graphics.setColor(0.96, 0.95, 0.92, on and 1 or 0.9)
        local name = def.name or c.item.id
        if (c.item.level or 0) > 0 then name = name .. " +" .. c.item.level end -- the Anvil's "+n"
        love.graphics.print(Theme.ellipsize(name, self.rowFont, r.w - 44 - rankW - 12), r.x + 32,
            r.y + (r.h - self.rowFont:getHeight()) / 2)
        Theme.set(Theme.muted, 0.9)
        love.graphics.print(rank, r.x + r.w - rankW - 10, r.y + (r.h - self.rowFont:getHeight()) / 2)
    end

    local b = self.button
    local ready = self:ready()
    local focused = (self.focus == self:slots())
    love.graphics.setColor(0.12, 0.13, 0.16, focused and 0.95 or 0.7)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 7, 7)
    love.graphics.setColor(0.62, 0.38, 0.72, ready and (focused and 1 or 0.7) or 0.3)
    love.graphics.setLineWidth((focused and ready) and 2 or 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 7, 7)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.buttonFont)
    love.graphics.setColor(0.96, 0.95, 0.92, ready and 1 or 0.45)
    love.graphics.printf(self:buttonLabel(), b.x, b.y + (b.h - self.buttonFont:getHeight()) / 2, b.w, "center")

    if not InputMode.touch then
        local pad = InputMode.isGamepad()
        local hint = pad and "D-pad move  -  A pick  -  B leave" or "Arrows move  -  Enter pick  -  Esc leave"
        love.graphics.setFont(self.hintFont)
        love.graphics.setColor(0.55, 0.6, 0.7)
        love.graphics.printf(hint, bx, by + self.boxH - 22, self.boxW, "center")
    end
    if self.onClose then self.closeButton:draw() end
    love.graphics.setColor(1, 1, 1)
end

function MawPanel:mousemoved(x, y)
    if self.onClose then self.closeButton:mousemoved(x, y) end
    for i, c in ipairs(self.candidates) do if inRect(c.rect, x, y) then self.focus = i; return end end
    if inRect(self.button, x, y) then self.focus = self:slots() end
end

function MawPanel:cursorKind(x, y)
    if self.onClose and self.closeButton:contains(x, y) then return "hand" end
    for _, c in ipairs(self.candidates) do if inRect(c.rect, x, y) then return "hand" end end
    if inRect(self.button, x, y) then return self:ready() and "hand" or "arrow" end
    return "arrow"
end

function MawPanel:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.onClose and self.closeButton:mousepressed(x, y, button) then self:close(); return end
    for i, c in ipairs(self.candidates) do if inRect(c.rect, x, y) then self:toggle(i); return end end
    if inRect(self.button, x, y) then self:feed() end
end

-- Up and down walk a column; left and right jump between them; past the last row is the button.
function MawPanel:move(dx, dy)
    local n, slots = #self.candidates, self:slots()
    if self.focus == slots then
        if dy < 0 and n > 0 then self.focus = n end
        return
    end
    if dy ~= 0 then
        local f = self.focus + dy
        if f < 1 then f = 1 end
        if f > n then f = slots end
        self.focus = f
    elseif dx ~= 0 then
        local f = self.focus + dx * ROWS_PER_COL
        if f >= 1 and f <= n then self.focus = f end
    end
end

function MawPanel:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" or key == "w" then self:move(0, -1)
    elseif key == "down" or key == "s" then self:move(0, 1)
    elseif key == "left" or key == "a" then self:move(-1, 0)
    elseif key == "right" or key == "d" then self:move(1, 0)
    elseif key == "return" or key == "kpenter" or key == "space" then self:activate(self.focus) end
end

function MawPanel:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" then self:move(0, -1)
    elseif button == "dpdown" then self:move(0, 1)
    elseif button == "dpleft" then self:move(-1, 0)
    elseif button == "dpright" then self:move(1, 0)
    elseif button == "a" then self:activate(self.focus)
    elseif button == "start" then self:feed() end
end

return MawPanel
