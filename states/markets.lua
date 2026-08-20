-- THE MARKETS: the square the city's shelves stand around, and the second board of cards in the game.
--
-- WHY IT IS A SCREEN RATHER THAN A PANEL. Fifteen cards on the city board, seven of them the same kind
-- of thing -- a shelf you browse -- and eleven of the fifteen shut on a fresh save. The city read as a
-- wall of locked plates instead of a town, and the one door a new player could use was buried among
-- them. The shelves moved behind one Markets card (data/buildings/markets.lua) and onto this board,
-- which took the city from four rows to two and left every card on it something you can walk into.
--
-- A whole state, like the Gate, because a shop is already a pop-up: hosting the market as a panel would
-- put the shelf in a second overlay stacked on the first, over a painted city, which is a worse place to
-- read a price than a room of its own.
--
-- IT IS THE SAME BOARD WIDGET, and deliberately so. `district = "market"` is the only thing that says a
-- card belongs here rather than in the city (models/building.lua), and everything else -- the lattice,
-- the locked "???" plate, the red unseen dot, mouse/keyboard/gamepad -- comes from ui/building_map.lua
-- unchanged. A second hand-rolled grid would be a second set of these behaviours to keep in step.
--
-- What a shop SAYS before it opens is models/vendor_visit.lua, shared with the city for the same reason.

local State = require("states")
local Building = require("models.building")
local BuildingMap = require("ui.building_map")
local CloseButton = require("ui.close_button")
local Errand = require("models.errand")
local Player = require("models.player")
local Scale = require("scale")
local Theme = require("ui.theme")
local VendorVisit = require("models.vendor_visit")

local markets = {}

local titleFont = Theme.display(28)
local subFont = Theme.body(14)

local map          -- BuildingMap widget over the market district
local activePanel  -- the open shop panel, or nil
local back         -- CloseButton: the mouse's way out (see docs -- the game is playable mouse-only)

local function toCity()
    Player.active = markets.player
    State.switch(require("states.hub"))
end

local function dismissPanel()
    activePanel = nil
    require("models.sound").play("ui.cancel")
end

-- Open a stall's shelf. Every card here names a vendor, so this is always the shop panel -- but it is
-- routed through `panel` rather than hardcoded, so a future counter that is not a shelf (a bank, a
-- courier) needs a blueprint and nothing here.
local function openShelf(building)
    local moduleName = building.panel or "placeholder"
    local ok, PanelModule = pcall(require, "ui.panels." .. moduleName)
    if not ok then PanelModule = require("ui.panels.placeholder") end
    activePanel = PanelModule.new({
        title = building.name,
        player = markets.player,
        vendor = building.vendor,
        onClose = dismissPanel,
    })
end

local function openStall(building)
    if not building.vendor then openShelf(building); return end
    VendorVisit.play(markets.player, building.vendor, function() openShelf(building) end)
end

function markets.enter(self, opts)
    opts = opts or {}
    markets.player = opts.player or Player.active
    activePanel = nil
    require("models.sound").music("music.hub")
    require("ui.screen_fx").reset()

    map = BuildingMap.new(Building.list(markets.player, { district = "market" }), {
        onActivate = openStall,
        -- The red unseen dot, exactly as the city drew it for these cards before they moved: a house
        -- with work to ask for, or a shelf carrying wares that were put there and nobody has read. It is
        -- the one thing a square of eight counters cannot say any other way. The Markets card out in the
        -- city carries the OR of these (states/hub.lua) -- a request behind a door behind a door is a
        -- request nobody sees -- which is why the question is Errand.doorBadge's and not this closure's.
        badge = function(b)
            local deepest = markets.player.descentRun and markets.player.descentRun.cleared or 0
            return Errand.doorBadge(markets.player, b.vendor, deepest)
        end,
    })
    back = CloseButton.new(Scale.WIDTH - 24, 24)
end

function markets.update(dt)
    if activePanel then
        if activePanel.update then activePanel:update(dt) end
    else
        map:update(dt)
    end
end

function markets.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Markets", 0, 24, Scale.WIDTH, "center")

    love.graphics.setFont(subFont)
    Theme.set(Theme.muted)
    love.graphics.printf("Seven houses, and each opens on its own work.", 0, 66, Scale.WIDTH, "center")

    map:draw()
    back:draw()

    if activePanel then activePanel:draw() end
end

function markets.mousemoved(x, y, dx, dy)
    if activePanel then
        if activePanel.mousemoved then activePanel:mousemoved(x, y, dx, dy) end
        return
    end
    back:mousemoved(x, y)
    map:mousemoved(x, y)
end

function markets.mousepressed(x, y, button)
    if activePanel then
        if activePanel.mousepressed then activePanel:mousepressed(x, y, button) end
        return
    end
    if back:mousepressed(x, y, button) then toCity(); return end
    map:mousepressed(x, y, button)
end

function markets.mousereleased(x, y, button)
    if activePanel and activePanel.mousereleased then activePanel:mousereleased(x, y, button) end
end

function markets.wheelmoved(dx, dy)
    if activePanel and activePanel.wheelmoved then activePanel:wheelmoved(dx, dy) end
end

function markets.keypressed(key)
    if activePanel then
        if key == "escape" then dismissPanel(); return end
        if activePanel.keypressed then activePanel:keypressed(key) end
        return
    end
    if key == "escape" then toCity(); return end
    map:keypressed(key)
end

function markets.textinput(t)
    if activePanel and activePanel.textinput then activePanel:textinput(t) end
end

function markets.gamepadpressed(joystick, button)
    if activePanel then
        if button == "b" then dismissPanel(); return end
        if activePanel.gamepadpressed then activePanel:gamepadpressed(joystick, button) end
        return
    end
    if button == "b" then toCity(); return end
    map:gamepadpressed(joystick, button)
end

return markets
