local State = require("states")
local Menu = require("ui.menu")

local menu = {}

local titleFont = love.graphics.newFont(48)

local widget = Menu.new({
    {
        label = "Start Game",
        action = function()
            State.switch(require("states.hub"))
        end,
    },
    {
        label = "Exit To Desktop",
        action = function()
            love.event.quit()
        end,
    },
}, { startY = 280 })

function menu.update(dt)
    widget:update(dt)
end

function menu.draw()
    local screenW = love.graphics.getWidth()

    love.graphics.setBackgroundColor(0.10, 0.11, 0.15)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("LoveTactics", 0, 120, screenW, "center")

    widget:draw()
end

function menu.mousemoved(x, y)
    widget:mousemoved(x, y)
end

function menu.mousepressed(x, y, button)
    widget:mousepressed(x, y, button)
end

function menu.keypressed(key)
    widget:keypressed(key)
end

function menu.gamepadpressed(joystick, button)
    widget:gamepadpressed(joystick, button)
end

return menu
