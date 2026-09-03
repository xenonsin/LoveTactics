-- THE HOUSES: the square the city's class shelves stand around, and the second board of cards in the
-- game.
--
-- WHY IT IS A SCREEN RATHER THAN A PANEL. Seven shelves on the city plaza made it a wall of cards where
-- over half were the same kind of thing -- a shelf you browse -- which is the reading that moved them
-- off it once already. They live behind one card (data/buildings/houses.lua) and on this board, which
-- leaves every plate in the city something you walk into for a different reason. And a shop is already
-- a pop-up: hosting the square as a panel would put the shelf in a second overlay stacked on the first,
-- over a painted city, which is a worse place to read a price than a room of its own.
--
-- IT IS THE SAME BOARD WIDGET as the plaza, and deliberately so. `district = "houses"` is the only
-- thing that says a card belongs here rather than in the city (models/building.lua), and everything
-- else -- the lattice, the locked plate, the red unseen dot, mouse/keyboard/gamepad -- comes from
-- ui/building_map.lua unchanged. A second hand-rolled grid is a second set of these behaviours to keep
-- in step.
--
-- THE SUBTITLE CARRIES THE GATE, once, for all seven. Every shut plate here has the same answer -- climb
-- the class and its shelf is open -- so saying it on each of them is seven copies of one sentence, and
-- naming the house in it gives away the shop the plate exists to withhold (models/building.lua).
--
-- What a shop SAYS before it opens is models/vendor_visit.lua, shared with the city for the same reason
-- the widget is.

local State = require("states")
local Building = require("models.building")
local BuildingMap = require("ui.building_map")
local CloseButton = require("ui.close_button")
local Player = require("models.player")
local Scale = require("scale")
local Theme = require("ui.theme")
local Vendor = require("models.vendor")
local VendorVisit = require("models.vendor_visit")

local houses = {}

local titleFont = Theme.display(28)
local subFont = Theme.body(14)

local map          -- BuildingMap widget over the houses district
local activePanel  -- the open shop panel, or nil
local back         -- CloseButton: the mouse's way out (the game is playable mouse-only)

local function toCity()
    Player.active = houses.player
    State.switch(require("states.hub"))
end

local function dismissPanel()
    activePanel = nil
    require("models.sound").play("ui.cancel")
end

-- Open a house's shelf. Every card here names a vendor, so this is always the shop panel -- but it is
-- routed through `panel` rather than hardcoded, so a later counter that is not a shelf needs a
-- blueprint and nothing here.
local function openShelf(building)
    local moduleName = building.panel or "placeholder"
    local ok, PanelModule = pcall(require, "ui.panels." .. moduleName)
    if not ok then PanelModule = require("ui.panels.placeholder") end
    activePanel = PanelModule.new({
        title = building.name,
        player = houses.player,
        vendor = building.vendor,
        onClose = dismissPanel,
    })
end

local function openHouse(building)
    if not building.vendor then openShelf(building); return end
    VendorVisit.play(houses.player, building.vendor, function() openShelf(building) end)
end

function houses.enter(self, opts)
    opts = opts or {}
    houses.player = opts.player or Player.active
    activePanel = nil
    require("models.sound").music("music.hub")
    require("ui.screen_fx").reset()

    local cards = Building.list(houses.player, { district = "houses" })
    map = BuildingMap.new(cards, {
        onActivate = openHouse,
        -- The red unseen dot: this shelf is carrying wares the player has never looked at -- a rung
        -- their class level opened while they were underground, which is the one thing a square of
        -- seven counters cannot say any other way. The Houses card out in the city carries the OR of
        -- these (states/hub.lua), since a mark behind a door behind a door is a mark nobody sees.
        badge = function(b)
            return Vendor.hasMarkedStock(b.vendor, houses.player and houses.player.newStock)
        end,
    })
    back = CloseButton.new(Scale.WIDTH - 24, 24)

    -- ARRIVING ON ONE COUNTER. The Roll walks a body to the house that teaches the class it is standing
    -- on (ui/class_editor.lua), and that walk should land AT the shelf: the player has already made the
    -- choice the square is for, and a board with the right card merely highlighted would ask it again.
    -- It is the same door either way -- the greeting plays, the shelf is the shelf -- and closing it
    -- leaves them here, in the square, which is where they now are.
    --
    -- A shut card is not opened by naming it. The button that sends them here is drawn shut too, so
    -- this can only be reached past an open door; the guard is for a caller that goes stale, not for
    -- a player.
    if opts.open then
        for _, card in ipairs(cards) do
            if card.id == opts.open and not card.locked then openHouse(card) end
        end
    end
end

function houses.update(dt)
    if activePanel then
        if activePanel.update then activePanel:update(dt) end
    else
        map:update(dt)
    end
end

function houses.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Houses", 0, 24, Scale.WIDTH, "center")

    love.graphics.setFont(subFont)
    Theme.set(Theme.muted)
    love.graphics.printf("Seven shelves. Each opens at level 1 of its own class, and deepens as it climbs.",
        0, 66, Scale.WIDTH, "center")

    map:draw()
    back:draw()

    if activePanel then activePanel:draw() end
end

function houses.mousemoved(x, y, dx, dy)
    if activePanel then
        if activePanel.mousemoved then activePanel:mousemoved(x, y, dx, dy) end
        return
    end
    back:mousemoved(x, y)
    map:mousemoved(x, y)
end

function houses.mousepressed(x, y, button)
    if activePanel then
        if activePanel.mousepressed then activePanel:mousepressed(x, y, button) end
        return
    end
    if back:mousepressed(x, y, button) then toCity(); return end
    map:mousepressed(x, y, button)
end

function houses.mousereleased(x, y, button)
    if activePanel and activePanel.mousereleased then activePanel:mousereleased(x, y, button) end
end

function houses.wheelmoved(dx, dy)
    if activePanel and activePanel.wheelmoved then activePanel:wheelmoved(dx, dy) end
end

function houses.keypressed(key)
    if activePanel then
        if key == "escape" then dismissPanel(); return end
        if activePanel.keypressed then activePanel:keypressed(key) end
        return
    end
    if key == "escape" then toCity(); return end
    map:keypressed(key)
end

function houses.textinput(t)
    if activePanel and activePanel.textinput then activePanel:textinput(t) end
end

function houses.gamepadpressed(joystick, button)
    if activePanel then
        if button == "b" then dismissPanel(); return end
        if activePanel.gamepadpressed then activePanel:gamepadpressed(joystick, button) end
        return
    end
    if button == "b" then toCity(); return end
    map:gamepadpressed(joystick, button)
end

function houses:cursorKind(x, y)
    if activePanel then
        return activePanel.cursorKind and activePanel:cursorKind(x, y) or "arrow"
    end
    if back:contains(x, y) then return "hand" end
    return map:mouseOverBuilding(x, y) and "hand" or "arrow"
end

return houses
