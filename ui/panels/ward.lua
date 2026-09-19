-- THE WARD'S COUNTER: the two ways out of a wound, one row each, per hurt body.
--
-- See data/buildings/cathedral.lua for what this room is and models/wound.lua's ward block for why it is
-- allowed to charge for anything at all. In one line: REST is free forever and TREAT buys only speed,
-- so the gold is priced against impatience rather than against injury.
--
-- TWO ROWS PER BODY RATHER THAN ONE ROW THAT OPENS A CHOOSER. A body carried out three times is three
-- separate decisions and the interesting one is where paying stops being worth it -- so both prices sit
-- on screen beside each other, on every body, all the time. A chooser would hide the comparison one
-- click deep and make "mend everybody" the obvious press.
--
-- A ROW THAT CANNOT BE PRESSED IS NOT DRAWN AS A ROW. Treat disappears when the purse is short rather
-- than greying, because a control appears only where it is legal -- and the purse is on the header, so
-- the player is never left guessing which of the two facts stopped them.
--
-- THE RESTING ARE LISTED AND NOT ACTIONABLE. They are the cost of the free path made visible: four
-- bodies go down, and a name sitting in this list is a name that is not among them. Without the list
-- the deployment picker is simply short a body for a reason the player chose two screens ago.

local CloseButton = require("ui.close_button")
local Menu = require("ui.menu")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")
local Sound = require("models.sound")
local Wound = require("models.wound")

local Ward = {}
Ward.__index = Ward

local BOX_W, BOX_H = 560, 420
local ROW_W, ROW_H = 470, 40

function Ward.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Ward)
    self.player = opts.player
    self.onClose = opts.onClose
    self.titleFont = Theme.display(30)
    self.bodyFont = Theme.body(17)
    self.rowFont = Theme.body(18)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    self:rebuild()
    return self
end

-- The rows, rebuilt after every press: treating drops a wound and resting takes a body off the list
-- entirely, so the menu the player is looking at is stale the instant either one lands.
function Ward:rebuild()
    local p = self.player
    local items = {}
    for _, entry in ipairs(Wound.wounded(p)) do
        local char, n = entry.char, entry.count
        local name = char.name or char.id
        if (p.gold or 0) >= Wound.TREAT_COST then
            items[#items + 1] = {
                label = string.format("Set %s's bone  -  %dg", name, Wound.TREAT_COST),
                action = function()
                    if Wound.treat(p, char.id) then Sound.play("ui.confirm") end
                    self:rebuild()
                end,
            }
        end
        items[#items + 1] = {
            label = string.format("Rest %s  -  %d descents", name, n * Wound.REST_DESCENTS),
            action = function()
                if Wound.rest(p, char.id) > 0 then Sound.play("ui.confirm") end
                self:rebuild()
            end,
        }
    end
    self.items = items
    self.menu = #items > 0 and Menu.new(items, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = 8,
        startY = self.boxY + 120,
        centerX = Scale.WIDTH / 2,
        font = self.rowFont,
        maxVisible = 5,
    }) or nil
end

function Ward:close()
    if self.onClose then self.onClose() end
end

function Ward:update(dt) if self.menu then self.menu:update(dt) end end

function Ward:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    -- The house's desk calls this room the Inn and so does this panel (data/buildings/cathedral.lua
    -- explains why the FILE is still ward.lua). One name, two surfaces, and they have to agree.
    love.graphics.printf("Inn", self.boxX, self.boxY + 26, BOX_W, "center")

    -- The purse, on the header, because one of the two prices is in gold and the other is not -- so the
    -- number that decides which rows exist has to be readable without closing the panel.
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    love.graphics.printf(string.format("%dg", (self.player and self.player.gold) or 0),
        self.boxX, self.boxY + 66, BOX_W - 24, "right")

    if self.menu then
        self.menu:draw()
    else
        Theme.set(Theme.ink)
        love.graphics.printf("Nobody here is hurt.", self.boxX, self.boxY + 150, BOX_W, "center")
    end

    -- Who is lying up, and for how much longer. Below the rows rather than mixed among them: these are
    -- not choices, they are the bill for choices already made.
    local resting = Wound.resters(self.player)
    if #resting > 0 then
        local y = self.boxY + BOX_H - 74 - (#resting - 1) * 20
        Theme.set(Theme.muted)
        love.graphics.setFont(self.bodyFont)
        for _, r in ipairs(resting) do
            love.graphics.printf(string.format("%s is resting  -  %d descents left",
                r.char.name or r.char.id, r.left), self.boxX + 24, y, BOX_W - 48, "left")
            y = y + 20
        end
    end

    Theme.set(Theme.muted)
    love.graphics.setFont(self.bodyFont)
    love.graphics.printf(InputMode.pick("B to close", "Tap X to close", "Click X, or Esc to close"),
        self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function Ward:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    if self.menu then self.menu:mousemoved(x, y) end
end

function Ward:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if self.menu and self.menu.cursorKind then return self.menu:cursorKind(x, y) end
    return "arrow"
end

function Ward:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) or not isInsideBox(self, x, y) then
        self:close()
        return
    end
    if self.menu then self.menu:mousepressed(x, y, button) end
end

function Ward:keypressed(key)
    if key == "escape" then self:close(); return end
    if self.menu then self.menu:keypressed(key) end
end

function Ward:gamepadpressed(joystick, button)
    if button == "b" then self:close(); return end
    if self.menu then self.menu:gamepadpressed(joystick, button) end
end

return Ward
