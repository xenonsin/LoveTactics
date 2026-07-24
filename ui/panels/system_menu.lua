-- The system menu: the pop-up behind the hub's burger button. Settings, leave to the title screen,
-- and resume.
--
-- This is the door states/settings.lua's own header asked for -- "the second one -- a pause menu, a
-- hub key -- should not have to strand the player at the title screen to get here". It hands itself
-- to the settings screen as the state to come back to, so Back returns to the city rather than to the
-- menu. (That only actually worked once `settings.enter` was fixed to take `self` first; before that
-- the screen took ITSELF as the return state and could not be left at all.)
--
-- Rows are ui/menu.lua, which is what gets this mouse, keyboard and gamepad without three code paths.
-- The close button and the click-outside-to-dismiss are ui/panels/placeholder.lua's contract, followed
-- exactly, so a modal behaves the same wherever the player meets one.
--
--   local panel = SystemMenu.new({ player = player, onClose = fn, returnTo = hub })

local Menu = require("ui.menu")
local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")

local SystemMenu = {}
SystemMenu.__index = SystemMenu

local BOX_W, BOX_H = 380, 300
local ROW_W, ROW_H, ROW_SPACING = 300, 46, 12

function SystemMenu.new(opts)
    opts = opts or {}
    local self = setmetatable({}, SystemMenu)
    self.onClose = opts.onClose
    self.player = opts.player
    -- The state the settings screen returns to. The caller passes itself, so this panel never has to
    -- know which screen it was opened over.
    self.returnTo = opts.returnTo

    self.titleFont = love.graphics.newFont(26)
    self.hintFont = love.graphics.newFont(15)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    self.widget = Menu.new({
        { label = "Settings", action = function()
            local State = require("states")
            State.switch(require("states.settings"), self.returnTo)
        end },
        { label = "Main Menu", action = function()
            -- Save on the way out. The hub is a safe point and progress is already written at every
            -- purchase and quest, so this costs nothing and closes the one window where a player could
            -- leave from the city and lose a moment of it.
            local Player = require("models.player")
            Player.save()
            require("states").switch(require("states.menu"))
        end },
        { label = "Resume", action = function() self:close() end },
    }, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + 92,
    })

    return self
end

function SystemMenu:close()
    if self.onClose then self.onClose() end
end

function SystemMenu:update(dt)
    self.widget:update(dt)
end

function SystemMenu:draw()
    -- Dim the city behind the panel.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Menu", self.boxX, self.boxY + 34, BOX_W, "center")

    self.widget:draw()

    love.graphics.setFont(self.hintFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    local hint = InputMode.isGamepad() and "B to close" or "Click X, or Esc to close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function SystemMenu:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.widget:mousemoved(x, y)
end

-- Hand over the close X and any row under the pointer; arrow over the rest. See ui/cursor.lua.
function SystemMenu:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    return self.widget:mouseOverItem(x, y) and "hand" or "arrow"
end

function SystemMenu:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then return self:close() end
    -- A click outside the box dismisses, exactly as it does on every other panel. Checked BEFORE the
    -- rows so a click in the gap between them cannot fall through to nothing.
    if not isInsideBox(self, x, y) then return self:close() end
    self.widget:mousepressed(x, y, button)
end

function SystemMenu:keypressed(key)
    if key == "escape" then return self:close() end
    self.widget:keypressed(key)
end

function SystemMenu:gamepadpressed(joystick, button)
    -- Start closes as well as B: the button that opened the menu should shut it, which is what every
    -- pause menu the player has ever used does.
    if button == "b" or button == "start" then return self:close() end
    self.widget:gamepadpressed(joystick, button)
end

return SystemMenu
