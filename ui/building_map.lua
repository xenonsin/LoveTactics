-- Clickable building-hotspot widget for the hub city.
--
-- Like ui/menu.lua it gives every screen mouse + keyboard + gamepad for free,
-- but the items are positioned at data-defined rects over a background image
-- rather than in a vertical list. Locked buildings render dimmed and are
-- skipped by keyboard/gamepad navigation.
--
--   local BuildingMap = require("ui.building_map")
--   local map = BuildingMap.new(Building.list(prestige), {
--       onActivate = function(building) ... end,
--   })
--
--   -- in your state:
--   map:update(dt); map:draw()
--   map:mousemoved(x, y); map:mousepressed(x, y, button)
--   map:keypressed(key); map:gamepadpressed(joystick, button)

local Theme = require("ui.theme")
local Glyphs = require("ui.glyphs")

local BuildingMap = {}
BuildingMap.__index = BuildingMap

local DEFAULTS = {
    axisThreshold = 0.5, -- analog stick deflection needed to register a move
}

function BuildingMap.new(buildings, opts)
    opts = opts or {}
    local self = setmetatable({}, BuildingMap)
    self.buildings = buildings
    self.onActivate = opts.onActivate
    -- Optional `badge(building)` predicate: true puts the red unseen dot in that plate's top-right
    -- corner (ui/glyphs.lua). Asked every frame rather than baked in at construction, because what it
    -- reports (a shop holding wares the player has not looked at) is cleared inside a panel this same
    -- map is still sitting behind -- closing the shop should take the dot with it.
    self.badge = opts.badge
    self.font = opts.font or Theme.display(18)
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.axisActive = false
    self.selected = self:firstSelectable() or 1
    return self
end

-- Index of the first non-locked building, or nil if all are locked.
function BuildingMap:firstSelectable()
    for i, b in ipairs(self.buildings) do
        if not b.locked then return i end
    end
    return nil
end

local function isInside(b, px, py)
    return px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h
end

-- Move selection by delta, wrapping and skipping locked buildings.
function BuildingMap:moveSelection(delta)
    local count = #self.buildings
    if count == 0 then return end
    for _ = 1, count do
        self.selected = (self.selected - 1 + delta) % count + 1
        if not self.buildings[self.selected].locked then return end
    end
end

function BuildingMap:activate()
    local b = self.buildings[self.selected]
    if b and not b.locked and self.onActivate then
        self.onActivate(b)
    end
end

function BuildingMap:update(dt)
    -- Analog stick (left stick X) cycles buildings, edge-detected so a held
    -- stick advances one step per push.
    local moved = false
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            local x = joystick:getGamepadAxis("leftx")
            if x <= -self.axisThreshold then
                if not self.axisActive then self:moveSelection(-1) end
                moved = true
            elseif x >= self.axisThreshold then
                if not self.axisActive then self:moveSelection(1) end
                moved = true
            end
        end
    end
    self.axisActive = moved
end

function BuildingMap:draw()
    love.graphics.setFont(self.font)
    for i, b in ipairs(self.buildings) do
        local active = (i == self.selected) and not b.locked

        -- Hotspot plates sit over the painted city, so they stay a touch translucent.
        if b.locked then Theme.set(Theme.slot, 0.7)
        elseif active then Theme.set(Theme.panel, 0.85)
        else Theme.set(Theme.panel2, 0.7) end
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, Theme.R, Theme.R)

        love.graphics.setLineWidth(active and 1.5 or 1)
        if active then Theme.set(Theme.accentAmber)
        elseif b.locked then Theme.set(Theme.frame, 0.5)
        else Theme.set(Theme.frame) end
        love.graphics.rectangle("line", b.x, b.y, b.w, b.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(1)

        local label = b.locked and ("? (prestige " .. b.unlockPrestige .. ")") or b.name
        Theme.set(active and Theme.accentAmber or (b.locked and Theme.muted or Theme.ink))
        love.graphics.printf(label, b.x, b.y + b.h / 2 - 10, b.w, "center")

        -- The unseen dot rides the corner of the plate itself, so the city tells you which door to
        -- walk through before you have opened any of them. A locked building never carries one.
        if not b.locked and self.badge and self.badge(b) then
            Glyphs.unseenDot(b.x + b.w - 10, b.y + 10, 5)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Mouse hover selects the hovered building so all input methods stay in sync.
function BuildingMap:mousemoved(x, y)
    for i, b in ipairs(self.buildings) do
        if not b.locked and isInside(b, x, y) then
            self.selected = i
            return
        end
    end
end

function BuildingMap:mousepressed(x, y, button)
    if button ~= 1 then return end
    for i, b in ipairs(self.buildings) do
        if not b.locked and isInside(b, x, y) then
            self.selected = i
            self:activate()
            return
        end
    end
end

-- True when the point is over an unlocked (clickable) building, so a state can show the hand cursor.
function BuildingMap:mouseOverBuilding(x, y)
    for _, b in ipairs(self.buildings) do
        if not b.locked and isInside(b, x, y) then return true end
    end
    return false
end

function BuildingMap:keypressed(key)
    if key == "left" or key == "a" or key == "up" or key == "w" then
        self:moveSelection(-1)
    elseif key == "right" or key == "d" or key == "down" or key == "s" then
        self:moveSelection(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activate()
    end
end

function BuildingMap:gamepadpressed(joystick, button)
    if button == "dpleft" or button == "dpup" then
        self:moveSelection(-1)
    elseif button == "dpright" or button == "dpdown" then
        self:moveSelection(1)
    elseif button == "a" or button == "start" then
        self:activate()
    end
end

return BuildingMap
