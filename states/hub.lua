-- Hub city state: the town screen reached from the main menu. Buildings are
-- clickable hotspots over a background image; clicking one opens a modal pop-up
-- panel (Quest Board, or a placeholder for buildings not yet designed). The
-- city grows as the player's prestige unlocks more buildings (see
-- models/building.lua and data/buildings/).

local State = require("states")
local Player = require("models.player")
local Building = require("models.building")
local Sprite = require("models.sprite")
local BuildingMap = require("ui.building_map")

local hub = {}

local titleFont = love.graphics.newFont(28)

local map           -- BuildingMap widget
local background    -- love Image, or a path string if the asset is missing
local activePanel   -- the open pop-up panel, or nil

-- Open the pop-up panel for a building. Buildings name a module under
-- ui/panels/; anything without one falls back to the generic placeholder.
local function openPanel(building)
    local moduleName = building.panel or "placeholder"
    local ok, PanelModule = pcall(require, "ui.panels." .. moduleName)
    if not ok then
        PanelModule = require("ui.panels.placeholder")
    end
    activePanel = PanelModule.new({
        title = building.name,
        prestige = hub.player and hub.player.prestige or 1,
        onClose = function() activePanel = nil end,
    })
end

function hub.enter()
    hub.player = Player.new()
    activePanel = nil
    background = Sprite.load("assets/hub/city.png")
    map = BuildingMap.new(Building.list(hub.player.prestige), {
        onActivate = openPanel,
    })
end

function hub.update(dt)
    if activePanel then
        activePanel:update(dt)
    else
        map:update(dt)
    end
end

function hub.draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Background: draw the image if it loaded, else a solid fallback.
    if type(background) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(background, 0, 0,
            0, screenW / background:getWidth(), screenH / background:getHeight())
    else
        love.graphics.setBackgroundColor(0.09, 0.08, 0.11)
    end

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("The Hub", 0, 24, screenW, "center")

    map:draw()

    if activePanel then
        activePanel:draw()
    end
end

function hub.mousemoved(x, y, dx, dy)
    if activePanel then
        activePanel:mousemoved(x, y)
    else
        map:mousemoved(x, y)
    end
end

function hub.mousepressed(x, y, button)
    if activePanel then
        activePanel:mousepressed(x, y, button)
    else
        map:mousepressed(x, y, button)
    end
end

function hub.keypressed(key)
    if activePanel then
        activePanel:keypressed(key)
    elseif key == "escape" then
        State.switch(require("states.menu"))
    else
        map:keypressed(key)
    end
end

function hub.gamepadpressed(joystick, button)
    if activePanel then
        activePanel:gamepadpressed(joystick, button)
    else
        map:gamepadpressed(joystick, button)
    end
end

return hub
