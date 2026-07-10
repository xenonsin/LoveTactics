local State = require("states")
local Menu = require("ui.menu")
local Player = require("models.player")
local Scale = require("scale")

local menu = {}

local titleFont = love.graphics.newFont(48)
local hintFont = love.graphics.newFont(16)

local widget

-- Built on entry, not at require time: whether "Continue" belongs on the menu depends on
-- whether a save exists, and that can change while the game is running (starting a new
-- game writes one; there is no save until the first quest is completed or purchase made).
local function buildMenu()
    local items = {}

    if Player.hasSave() then
        items[#items + 1] = {
            label = "Continue",
            action = function()
                Player.start()
                State.switch(require("states.hub"))
            end,
        }
    end

    items[#items + 1] = {
        label = "New Game",
        action = function()
            Player.start(true) -- discards any save
            State.switch(require("states.hub"))
        end,
    }

    items[#items + 1] = {
        label = "Exit To Desktop",
        action = function() love.event.quit() end,
    }

    return Menu.new(items, { startY = 280 })
end

function menu.enter()
    widget = buildMenu()
end

function menu.update(dt)
    widget:update(dt)
end

function menu.draw()
    local screenW = Scale.WIDTH

    -- Fill the logical area explicitly: letterbox bars are cleared to black, so
    -- setBackgroundColor (which paints the whole real window) can't be used here.
    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("LoveTactics", 0, 120, screenW, "center")

    widget:draw()

    if Player.hasSave() then
        love.graphics.setFont(hintFont)
        love.graphics.setColor(0.5, 0.55, 0.7)
        love.graphics.printf("New Game erases your save.", 0, Scale.HEIGHT - 48, screenW, "center")
    end
    love.graphics.setColor(1, 1, 1)
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
