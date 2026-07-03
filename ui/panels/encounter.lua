-- Modal encounter pop-up, opened when the player steps onto an encounter tile on
-- the overworld. Modeled on ui/panels/placeholder.lua: a state owns it, forwards
-- input while it is open, and it closes via the X button, Esc, or gamepad B.
--
-- Combat is a later system; for now "Resolve" simply fires opts.onResolve (the
-- game state marks the encounter cleared, and completes the quest if it was the
-- objective).
--
--   local panel = Encounter.new({
--       encounter = cell.encounter,      -- { kind, name }
--       onResolve = function() ... end,  -- Resolve / Fight pressed
--       onClose   = function() ... end,  -- dismissed without resolving
--   })

local CloseButton = require("ui.close_button")
local Scale = require("scale")

local Encounter = {}
Encounter.__index = Encounter

local BOX_W, BOX_H = 460, 240

local KIND_TEXT = {
    combat = "A hostile blocks the trail. Stand and fight.",
    elite = "A fearsome foe lurks here. Great risk, great reward.",
    town = "A safe waystation. Rest and resupply.",
    treasure = "An unguarded cache sits here. Claim what's inside.",
    objective = "Your quarry awaits. Defeat it to complete the quest.",
}

-- Verb shown on the resolve button for non-combat encounters.
local RESOLVE_LABEL = {
    town = "Enter",
    treasure = "Open",
}

function Encounter.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Encounter)
    self.encounter = opts.encounter or { kind = "combat" }
    self.onResolve = opts.onResolve
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(30)
    self.bodyFont = love.graphics.newFont(18)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    -- Resolve/Fight button along the bottom of the box.
    self.button = {
        x = self.boxX + BOX_W / 2 - 90,
        y = self.boxY + BOX_H - 62,
        w = 180,
        h = 42,
        hovered = false,
    }
    self.resolveLabel = RESOLVE_LABEL[self.encounter.kind] or "Fight"
    return self
end

function Encounter:close()
    if self.onClose then self.onClose() end
end

function Encounter:resolve()
    if self.onResolve then self.onResolve() end
end

function Encounter:update(dt) end

function Encounter:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(self.encounter.name or self.encounter.kind,
        self.boxX, self.boxY + 34, BOX_W, "center")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.85, 0.85, 0.9)
    love.graphics.printf(KIND_TEXT[self.encounter.kind] or "",
        self.boxX + 30, self.boxY + 96, BOX_W - 60, "center")

    -- Resolve button.
    local b = self.button
    love.graphics.setColor(b.hovered and 0.35 or 0.22, b.hovered and 0.45 or 0.28,
        b.hovered and 0.35 or 0.24)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setColor(0.6, 0.7, 0.55)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf(self.resolveLabel, b.x, b.y + b.h / 2 - 10, b.w, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

local function inButton(b, x, y)
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function Encounter:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.button.hovered = inButton(self.button, x, y)
end

function Encounter:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
    elseif inButton(self.button, x, y) then
        self:resolve()
    end
end

function Encounter:keypressed(key)
    if key == "escape" then
        self:close()
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:resolve()
    end
end

function Encounter:gamepadpressed(_, button)
    if button == "b" then
        self:close()
    elseif button == "a" or button == "start" then
        self:resolve()
    end
end

return Encounter
