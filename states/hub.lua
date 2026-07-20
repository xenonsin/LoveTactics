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
local Scale = require("scale")

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
        player = hub.player, -- forwarded so a launched quest knows the active party
        vendor = building.vendor, -- vendor id, for buildings that are shops
        onClose = function() activePanel = nil end,
    })
end

function hub.enter()
    -- The session's one player, carried across every hub visit. Rebuilding it here (as this
    -- once did, via Player.new) would discard gold, reputation, and everything bought.
    hub.player = Player.active or Player.start()
    -- Coming home rests the company: health and mana refill. Attrition lasts a quest, not forever.
    Player.restore(hub.player)
    activePanel = nil
    background = Sprite.load("assets/hub/city.png")
    -- The whole player, not just their prestige: some doors are opened by a quest rather than by
    -- getting richer (Building.list).
    map = BuildingMap.new(Building.list(hub.player), {
        onActivate = openPanel,
    })

    -- Just back from a won quest? Surface the reward + the company's level-ups, then clear the handoff
    -- so it shows once (states/game.lua stashed it on the player before switching here).
    if hub.player.pendingSummary then
        local Advancement = require("ui.panels.advancement")
        activePanel = Advancement.new({
            reward = hub.player.pendingSummary,
            onClose = function() activePanel = nil end,
        })
        hub.player.pendingSummary = nil
    end
end

function hub.update(dt)
    if activePanel then
        activePanel:update(dt)
    else
        map:update(dt)
    end
end

function hub.draw()
    local screenW = Scale.WIDTH
    local screenH = Scale.HEIGHT

    -- Background: draw the image scaled to the logical area if it loaded, else a
    -- solid fallback rect (bars are cleared to black, so no setBackgroundColor).
    if type(background) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(background, 0, 0,
            0, screenW / background:getWidth(), screenH / background:getHeight())
    else
        love.graphics.setColor(0.09, 0.08, 0.11)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
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

-- Hand over a clickable building (see ui/cursor.lua), arrow elsewhere. When a panel is open the
-- city behind it is inert, so defer to the panel's own cursorKind (every panel has one).
function hub:cursorKind(x, y)
    if activePanel then
        return activePanel.cursorKind and activePanel:cursorKind(x, y) or "arrow"
    end
    return map:mouseOverBuilding(x, y) and "hand" or "arrow"
end

function hub.mousepressed(x, y, button)
    if activePanel then
        activePanel:mousepressed(x, y, button)
    else
        map:mousepressed(x, y, button)
    end
end

-- Only panels that scroll or drag define these; the city behind them has nothing to do with either.
function hub.mousereleased(x, y, button)
    if activePanel and activePanel.mousereleased then activePanel:mousereleased(x, y, button) end
end

function hub.wheelmoved(dx, dy)
    if activePanel and activePanel.wheelmoved then activePanel:wheelmoved(dx, dy) end
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
