-- Quest Board pop-up panel. Lists the quests the player can start (left column)
-- and shows details for the highlighted quest (right column). The quest list
-- reuses ui/menu.lua for three-input navigation; we read `menu.selected` each
-- frame to drive the detail pane. Starting a quest switches to the game state.
--
--   local panel = QuestBoard.new({ prestige = p.prestige, onClose = fn })

local State = require("states")
local Menu = require("ui.menu")
local Quest = require("models.quest")
local CloseButton = require("ui.close_button")

local QuestBoard = {}
QuestBoard.__index = QuestBoard

-- Panel box geometry, centered in the 800x600 window.
local BOX_W, BOX_H = 640, 400

function QuestBoard.new(opts)
    opts = opts or {}
    local self = setmetatable({}, QuestBoard)
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(30)
    self.headFont = love.graphics.newFont(20)
    self.bodyFont = love.graphics.newFont(16)

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    self.boxX = screenW / 2 - BOX_W / 2
    self.boxY = screenH / 2 - BOX_H / 2

    self.quests = Quest.available(opts.prestige or 1)

    -- Build the quest list. Selecting a quest starts it (placeholder game state).
    local items = {}
    for _, quest in ipairs(self.quests) do
        items[#items + 1] = {
            label = quest.name,
            action = function()
                State.switch(require("states.game"))
            end,
        }
    end

    -- Left column: narrow buttons anchored under the title.
    local leftColCenter = self.boxX + BOX_W * 0.28
    self.menu = Menu.new(items, {
        buttonWidth = 260,
        buttonHeight = 44,
        spacing = 12,
        startY = self.boxY + 90,
        centerX = leftColCenter,
        font = self.headFont,
    })

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function QuestBoard:close()
    if self.onClose then self.onClose() end
end

function QuestBoard:update(dt)
    self.menu:update(dt)
end

function QuestBoard:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Dim the city behind the panel.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel frame.
    love.graphics.setColor(0.12, 0.13, 0.18)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, 10, 10)

    -- Title.
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Quest Board", self.boxX, self.boxY + 24, BOX_W, "center")

    if #self.quests == 0 then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf("No quests available.", self.boxX, self.boxY + BOX_H / 2,
            BOX_W, "center")
    else
        -- Left: the quest list.
        self.menu:draw()

        -- Right: details for the highlighted quest.
        self:drawDetail()
    end

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.printf("Click a quest / Enter / A: Start    Click X / Esc / B: Close",
        self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self.closeButton:draw()

    love.graphics.setColor(1, 1, 1)
end

function QuestBoard:drawDetail()
    local quest = self.quests[self.menu.selected]
    if not quest then return end

    local x = self.boxX + BOX_W * 0.52
    local w = BOX_W * 0.42
    local y = self.boxY + 90

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf(quest.name, x, y, w, "left")

    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(quest.description, x, y + 40, w, "left")

    love.graphics.setColor(0.6, 0.65, 0.75)
    love.graphics.printf("Difficulty: " .. tostring(quest.difficulty), x, y + 130, w, "left")
    love.graphics.printf("Reward: " .. tostring(quest.rewardGold) .. " gold", x, y + 158, w, "left")
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function QuestBoard:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.menu:mousemoved(x, y)
end

function QuestBoard:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
    elseif not isInsideBox(self, x, y) then
        -- A click outside the panel dismisses the modal.
        self:close()
    else
        self.menu:mousepressed(x, y, button)
    end
end

function QuestBoard:keypressed(key)
    if key == "escape" then
        self:close()
    else
        self.menu:keypressed(key)
    end
end

function QuestBoard:gamepadpressed(joystick, button)
    if button == "b" then
        self:close()
    else
        self.menu:gamepadpressed(joystick, button)
    end
end

return QuestBoard
