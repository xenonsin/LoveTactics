-- SEND IT UP: choose a few pieces from the bag to send to the town stash (models/send_up.lua).
--
-- One panel for both routes -- the hoist on a floor and the Rift Mule's button -- because they are the
-- same choice: what, out of everything in a bag a wipe would empty, is worth making safe now. The host
-- says how many may go (`limit`) and what happens when they do (`onSend`); this only collects the pick.
--
-- Picking is free and reversible until Send: a row toggles in and out of the load, and the count beside
-- the button says how many of the limit are spoken for. Send with nothing picked does nothing, so the
-- hoist and the mule are never spent on an empty basket.
--
-- Same contract as the rest of ui/panels/: a state owns it and forwards input while it is open;
-- three-input (mouse + keyboard + gamepad) with a clickable X for a mouse-only player.
--
--   local panel = SendUp.new({
--       title    = "The Hoist",
--       prompt   = "A basket on a rope, up the shaft to the city. It goes once.",
--       items    = SendUpModel.candidates(player), -- live instances from the bag
--       limit    = 3,
--       onSend   = function(chosen) ... end,          -- the picked instances, in bag order
--       onClose  = function() ... end,
--   })

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Scale = require("scale")
local Theme = require("ui.theme")

local SendUp = {}
SendUp.__index = SendUp

local PAD = 28
local BOX_W = 620
local ROW_H, ROW_GAP = 34, 6
local VISIBLE = 8
local BTN_W, BTN_H, BTN_GAP = 170, 40, 16

local function inRect(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function SendUp.new(opts)
    opts = opts or {}
    local self = setmetatable({}, SendUp)
    self.title = opts.title or "Send Up"
    self.prompt = opts.prompt
    self.items = opts.items or {}
    self.limit = math.max(1, opts.limit or 1)
    self.onSend = opts.onSend
    self.onClose = opts.onClose
    self.picked = {}   -- [item] = true
    self.focus = 1     -- 1..#items are rows; #items + 1 is Send, #items + 2 is Leave
    self.scroll = 0    -- first visible row - 1
    self.notice = nil

    self.titleFont = Theme.display(26)
    self.promptFont = Theme.body(15)
    self.rowFont = Theme.body(15)
    self.hintFont = Theme.body(14)

    local rows = math.max(1, math.min(VISIBLE, #self.items))
    self.rows = rows
    self.boxW = BOX_W
    self.oPrompt = 58
    self.oList = self.oPrompt + self.promptFont:getHeight() * 2 + 18
    self.oButtons = self.oList + rows * ROW_H + (rows - 1) * ROW_GAP + 18
    self.oHint = self.oButtons + BTN_H + 14
    self.boxH = self.oHint + self.hintFont:getHeight() + PAD - 6
    self.boxX = math.floor(Scale.WIDTH / 2 - self.boxW / 2)
    self.boxY = math.floor(Scale.HEIGHT / 2 - self.boxH / 2)

    local bx = self.boxX + self.boxW / 2 - BTN_W - BTN_GAP / 2
    self.sendBtn = { x = bx, y = self.boxY + self.oButtons, w = BTN_W, h = BTN_H }
    self.leaveBtn = { x = bx + BTN_W + BTN_GAP, y = self.boxY + self.oButtons, w = BTN_W, h = BTN_H }
    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)
    return self
end

function SendUp:count()
    local n = 0
    for _ in pairs(self.picked) do n = n + 1 end
    return n
end

-- The rect of row `i` (1-based into self.items) if it is on screen, else nil.
function SendUp:rowRect(i)
    local v = i - self.scroll
    if v < 1 or v > self.rows then return nil end
    return {
        x = self.boxX + PAD,
        y = self.boxY + self.oList + (v - 1) * (ROW_H + ROW_GAP),
        w = self.boxW - PAD * 2, h = ROW_H,
    }
end

-- Toggle row `i` in or out of the load. Over the limit is refused out loud rather than silently.
function SendUp:toggle(i)
    local item = self.items[i]
    if not item then return end
    if self.picked[item] then
        self.picked[item] = nil
        self.notice = nil
    elseif self:count() >= self.limit then
        self.notice = "Only " .. self.limit .. " can go. Take one out first."
    else
        self.picked[item] = true
        self.notice = nil
    end
end

-- Send what is picked, in bag order. Nothing picked spends nothing.
function SendUp:send()
    local chosen = {}
    for _, item in ipairs(self.items) do
        if self.picked[item] then chosen[#chosen + 1] = item end
    end
    if #chosen == 0 then
        self.notice = "Pick something to send first."
        return
    end
    if self.onSend then self.onSend(chosen) end
end

function SendUp:close()
    if self.onClose then self.onClose() end
end

-- Keep the focused row on screen.
function SendUp:follow()
    if self.focus > #self.items then return end
    if self.focus <= self.scroll then self.scroll = self.focus - 1 end
    if self.focus > self.scroll + self.rows then self.scroll = self.focus - self.rows end
end

function SendUp:moveFocus(d)
    local n = #self.items + 2
    self.focus = (self.focus - 1 + d) % n + 1
    self:follow()
end

function SendUp:activate()
    local n = #self.items
    if self.focus <= n then self:toggle(self.focus)
    elseif self.focus == n + 1 then self:send()
    else self:close() end
end

-- ---- drawing ----------------------------------------------------------------

local function drawButton(r, label, focused, live, font)
    Theme.set(Theme.panel2 or Theme.panel)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    local edge = focused and Theme.accentAmber or Theme.frame
    love.graphics.setColor(edge[1], edge[2], edge[3], live and 1 or 0.45)
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(font)
    if live then Theme.set(Theme.ink or { 0.94, 0.93, 0.89 }) else Theme.set(Theme.muted) end
    love.graphics.printf(label, r.x, r.y + r.h / 2 - font:getHeight() / 2, r.w, "center")
end

function SendUp:drawRow(i)
    local r = self:rowRect(i)
    if not r then return end
    local item = self.items[i]
    local on = self.picked[item] == true
    local focused = (self.focus == i)
    love.graphics.setColor(0.07, 0.075, 0.085, on and 1 or 0.85)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    local edge = (focused or on) and Theme.accentAmber or Theme.frame
    love.graphics.setColor(edge[1], edge[2], edge[3], focused and 1 or (on and 0.8 or 0.4))
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setLineWidth(1)

    -- The tick box: the pick, at the row's left edge.
    local s = 16
    local bx, by = r.x + 10, r.y + r.h / 2 - s / 2
    love.graphics.setColor(0.6, 0.58, 0.52)
    love.graphics.rectangle("line", bx, by, s, s, 3, 3)
    if on then
        Theme.set(Theme.accentAmber)
        love.graphics.rectangle("fill", bx + 3, by + 3, s - 6, s - 6, 2, 2)
    end

    love.graphics.setFont(self.rowFont)
    local qty = (item.quantity or 1) > 1 and ("  x" .. item.quantity) or ""
    local label = Theme.ellipsize((item.name or item.id or "Item") .. qty, self.rowFont, r.w - 150)
    love.graphics.setColor(0.94, 0.93, 0.89)
    love.graphics.print(label, bx + s + 12, r.y + r.h / 2 - self.rowFont:getHeight() / 2)
    love.graphics.setColor(0.66, 0.61, 0.50)
    love.graphics.printf(item.type or "", r.x, r.y + r.h / 2 - self.rowFont:getHeight() / 2, r.w - 12, "right")
end

function SendUp:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, self.boxW, self.boxH, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 18, self.boxW, "center")

    love.graphics.setFont(self.promptFont)
    love.graphics.setColor(0.66, 0.61, 0.50)
    local line = self.notice or self.prompt or ""
    love.graphics.printf(line, bx + PAD, by + self.oPrompt, self.boxW - PAD * 2, "center")

    for i = self.scroll + 1, math.min(#self.items, self.scroll + self.rows) do self:drawRow(i) end
    -- More above or below: a thin mark at the list's edge, so a long bag reads as scrollable.
    love.graphics.setColor(0.6, 0.58, 0.52, 0.8)
    local cx = bx + self.boxW / 2
    if self.scroll > 0 then
        local y = by + self.oList - 8
        love.graphics.polygon("fill", cx - 8, y, cx + 8, y, cx, y - 6)
    end
    if self.scroll + self.rows < #self.items then
        local y = by + self.oList + self.rows * (ROW_H + ROW_GAP) - ROW_GAP + 4
        love.graphics.polygon("fill", cx - 8, y, cx + 8, y, cx, y + 6)
    end

    local n = #self.items
    drawButton(self.sendBtn, string.format("Send up  %d / %d", self:count(), self.limit),
        self.focus == n + 1, self:count() > 0, self.promptFont)
    drawButton(self.leaveBtn, "Leave", self.focus == n + 2, true, self.promptFont)

    local hint = InputMode.pick("D-pad choose  -  A pick  -  B leave", nil,
        "Arrows choose  -  Enter pick  -  Esc leave")
    if hint then
        love.graphics.setFont(self.hintFont)
        love.graphics.setColor(0.55, 0.6, 0.7)
        love.graphics.printf(hint, bx, by + self.oHint, self.boxW, "center")
    end

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function SendUp:rowAt(x, y)
    for i = self.scroll + 1, math.min(#self.items, self.scroll + self.rows) do
        if inRect(self:rowRect(i), x, y) then return i end
    end
    return nil
end

-- Hover never moves the pick, only the cursor that the keyboard drives.
function SendUp:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    local i = self:rowAt(x, y)
    if i then self.focus = i
    elseif inRect(self.sendBtn, x, y) then self.focus = #self.items + 1
    elseif inRect(self.leaveBtn, x, y) then self.focus = #self.items + 2 end
end

function SendUp:cursorKind(x, y)
    if self.closeButton:contains(x, y) or self:rowAt(x, y)
        or inRect(self.sendBtn, x, y) or inRect(self.leaveBtn, x, y) then
        return "hand"
    end
    return "arrow"
end

function SendUp:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close(); return end
    local i = self:rowAt(x, y)
    if i then self.focus = i; self:toggle(i); return end
    if inRect(self.sendBtn, x, y) then self:send(); return end
    if inRect(self.leaveBtn, x, y) then self:close(); return end
end

function SendUp:wheelmoved(_, dy)
    local maxScroll = math.max(0, #self.items - self.rows)
    self.scroll = math.max(0, math.min(maxScroll, self.scroll - (dy or 0)))
end

function SendUp:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" or key == "w" then self:moveFocus(-1)
    elseif key == "down" or key == "s" then self:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:activate() end
end

function SendUp:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" then self:moveFocus(-1)
    elseif button == "dpdown" then self:moveFocus(1)
    elseif button == "a" then self:activate()
    elseif button == "start" then self:send() end
end

return SendUp
