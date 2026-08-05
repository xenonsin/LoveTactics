-- The Fence: a wandering market on the trail (states/game.lua's openEncounter routes a `fence` cell
-- here). It offers a small, fixed stock of run relics (models/relic.lua) for gold, so the coin a run
-- forages or skims finally has somewhere to go ON the map instead of three menus later at the hub. Buy
-- what you can afford; leave the rest. Modeled on ui/panels/rest_choice.lua: a state owns it as
-- game.activePanel and forwards input; three-input + mouse-only.
--
--   Fence.new({ title=, stock={ {id, info, price}, ... }, gold=fn, onBuy=fn(entry)->bool, onClose= })
--
-- The caller does the real spend+grant in onBuy (returning true on success); the panel only tracks which
-- rows are sold and re-reads gold through the getter so affordability stays live as you spend.

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local RelicCard = require("ui.relic_card")
local Scale = require("scale")
local Theme = require("ui.theme")

local Fence = {}
Fence.__index = Fence

local BOX_W = 500
local PAD = 24
local ROW_H = 64
local ROW_GAP = 10

local GOLD = { 0.90, 0.78, 0.36 }

local function inRect(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function Fence.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Fence)
    self.title = opts.title or "The Fence"
    self.stock = opts.stock or {}
    self.gold = opts.gold or function() return 0 end
    self.onBuy = opts.onBuy
    self.onClose = opts.onClose
    self.finished = false
    self.focus = 1

    self.titleFont = Theme.display(28)
    self.goldFont = Theme.body(15)
    self.nameFont = Theme.display(18)
    self.tagFont = Theme.body(11)
    self.priceFont = Theme.body(16)
    self.hintFont = Theme.body(13)

    self.boxW = BOX_W
    self.boxH = 96 + math.max(1, #self.stock) * (ROW_H + ROW_GAP) + 20
    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - self.boxH / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    for i, entry in ipairs(self.stock) do
        entry.rect = {
            x = self.boxX + PAD, y = self.boxY + 84 + (i - 1) * (ROW_H + ROW_GAP),
            w = BOX_W - PAD * 2, h = ROW_H,
        }
    end
    return self
end

function Fence:buy(i)
    local entry = self.stock[i]
    if not entry or entry.bought then return end
    if self.gold() < (entry.price or 0) then return end -- can't afford: inert
    if self.onBuy and self.onBuy(entry) then entry.bought = true end
end

function Fence:close()
    if self.finished then return end
    self.finished = true
    if self.onClose then self.onClose() end
end

function Fence:draw()
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

    love.graphics.setFont(self.goldFont)
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
    love.graphics.printf("Your gold: " .. self.gold(), bx, by + 54, self.boxW - PAD, "right")

    local myGold = self.gold()
    for i, entry in ipairs(self.stock) do
        local r = entry.rect
        local info = entry.info or {}
        local accent = RelicCard.accentOf(info)
        local focused = (i == self.focus)
        local afford = not entry.bought and myGold >= (entry.price or 0)

        love.graphics.setColor(0.12, 0.13, 0.16, (focused and not entry.bought) and 0.95 or 0.55)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setColor(accent[1], accent[2], accent[3], entry.bought and 0.25 or (focused and 1 or 0.4))
        love.graphics.setLineWidth(focused and not entry.bought and 2 or 1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 7, 7)
        love.graphics.setLineWidth(1)

        local dim = entry.bought and 0.45 or 1
        RelicCard.gem(r.x + 22, r.y + r.h / 2 - 11, 22, 22, { accent[1] * dim, accent[2] * dim, accent[3] * dim })

        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(0.95 * dim, 0.94 * dim, 0.9 * dim, 1)
        love.graphics.print(info.name or entry.id, r.x + 42, r.y + 10)

        love.graphics.setFont(self.tagFont)
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.85 * dim)
        local tag = (info.alignment == "vice" and "VICE" or "VIRTUE") .. " · " .. (info.tier or "common"):upper()
        love.graphics.print(tag, r.x + 42, r.y + 38)

        -- Price / state, right-aligned.
        love.graphics.setFont(self.priceFont)
        local label, col
        if entry.bought then label, col = "Bought", { 0.55, 0.58, 0.62 }
        elseif not afford then label, col = (entry.price or 0) .. "g", { 0.7, 0.45, 0.42 }
        else label, col = (entry.price or 0) .. "g", GOLD end
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.printf(label, r.x, r.y + r.h / 2 - self.priceFont:getHeight() / 2, r.w - 16, "right")
    end

    local hint = InputMode.isGamepad() and "D-pad move  -  A buy  -  B leave"
        or "Arrows move  -  Enter buy  -  Esc leave"
    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf(hint, bx, by + self.boxH - 22, self.boxW, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

function Fence:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    for i, entry in ipairs(self.stock) do
        if inRect(entry.rect, x, y) then self.focus = i; break end
    end
end

function Fence:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for _, entry in ipairs(self.stock) do if inRect(entry.rect, x, y) then return "hand" end end
    return "arrow"
end

function Fence:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close(); return end
    for i, entry in ipairs(self.stock) do
        if inRect(entry.rect, x, y) then self:buy(i); return end
    end
end

function Fence:moveFocus(d)
    if #self.stock == 0 then return end
    self.focus = ((self.focus - 1 + d) % #self.stock) + 1
end

function Fence:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" or key == "w" then self:moveFocus(-1)
    elseif key == "down" or key == "s" then self:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:buy(self.focus) end
end

function Fence:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" then self:moveFocus(-1)
    elseif button == "dpdown" then self:moveFocus(1)
    elseif button == "a" or button == "start" then self:buy(self.focus) end
end

return Fence
