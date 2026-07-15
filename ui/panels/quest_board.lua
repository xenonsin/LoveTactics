-- Quest Board pop-up panel. Lists the quests the player can start (left column)
-- and shows details for the highlighted quest (right column). The quest list
-- reuses ui/menu.lua for three-input navigation; we read `menu.selected` each
-- frame to drive the detail pane. Starting a quest switches to the game state.
--
--   local panel = QuestBoard.new({ prestige = p.prestige, onClose = fn })

local State = require("states")
local Menu = require("ui.menu")
local Quest = require("models.quest")
local Player = require("models.player")
local Vendor = require("models.vendor")
local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")

local QuestBoard = {}
QuestBoard.__index = QuestBoard

-- Panel box geometry, centered in the 1280x720 logical space. The quest list grows without
-- bound as vendors gain quest lines, so it scrolls (Menu's `maxVisible`) rather than trying to
-- fit -- six rows at a time, with carets marking what is out of sight.
local BOX_W, BOX_H = 760, 520

local LIST_TOP = 96
local ROW_H, ROW_SPACING, MAX_VISIBLE = 44, 8, 6

function QuestBoard.new(opts)
    opts = opts or {}
    local self = setmetatable({}, QuestBoard)
    self.onClose = opts.onClose
    self.titleFont = love.graphics.newFont(30)
    self.headFont = love.graphics.newFont(20)
    self.bodyFont = love.graphics.newFont(16)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.prestige = opts.prestige or 1
    self.player = opts.player -- carried into the game state so the overworld sees the party
    -- The board is filtered by the whole player, not just prestige: finished quests drop off
    -- it, and a sponsor's later quests only appear once you have the reputation for them.
    self.quests = Quest.available(self.player)

    -- Build the quest list. Selecting a quest starts it: the game state generates
    -- the overworld map from the quest's `map` params, using the player's prestige
    -- to pick dynamic encounters (see states/game.lua, models/encounter.lua).
    --
    -- A `locked` quest is on the board but not startable: the Gate Below appears the moment you kill
    -- your first general and counts your keys until you have all seven (see Quest.available). Menu has
    -- no notion of a disabled row -- activation just calls `action` -- so the guard lives here, and it
    -- is the one thing standing between a one-key player and the Demon Lord.
    local items = {}
    for _, quest in ipairs(self.quests) do
        items[#items + 1] = {
            label = quest.locked and (quest.name .. " (Locked)") or quest.name,
            action = function()
                if quest.locked then return end
                -- Pick the deployable party before the overworld: party_select commits the choice
                -- and switches on to states.game with the same (quest, prestige, player).
                State.switch(require("states.party_select"), quest, self.prestige, self.player)
            end,
        }
    end

    -- Left column: narrow buttons anchored under the title, scrolling past MAX_VISIBLE.
    self.menu = Menu.new(items, {
        buttonWidth = 280,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + LIST_TOP,
        centerX = self.boxX + BOX_W * 0.26,
        font = self.headFont,
        maxVisible = MAX_VISIBLE,
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
    -- Dim the city behind the panel.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

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
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "A: Start    D-pad: Scroll    B: Close"
        or "Click a quest / Enter: Start    Wheel / PgUp / PgDn: Scroll    Click X / Esc: Close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self.closeButton:draw()

    love.graphics.setColor(1, 1, 1)
end

function QuestBoard:drawDetail()
    local quest = self.quests[self.menu.selected]
    if not quest then return end

    local x = self.boxX + BOX_W * 0.50
    local w = BOX_W * 0.44
    local y = self.boxY + LIST_TOP - 12

    love.graphics.setFont(self.headFont)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf(quest.name, x, y, w, "left")

    -- The sponsor is the reason to pick one quest over another, so it reads in the accent
    -- color directly under the name, with the player's standing beside it.
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(quest.sponsorName, x, y + 30, w, "left")

    if quest.sponsor then
        local rank = Player.repRank(self.player, quest.sponsor)
        love.graphics.setColor(0.6, 0.65, 0.75)
        love.graphics.printf(Vendor.rankName(quest.sponsor, rank), x, y + 50, w, "left")
    end

    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(quest.description, x, y + 78, w, "left")

    love.graphics.setColor(0.6, 0.65, 0.75)
    love.graphics.printf("Difficulty: " .. tostring(quest.difficulty), x, y + 168, w, "left")

    -- A locked quest has no reward to offer yet, only a tally and whatever the dead have given up.
    -- This is the whole endgame UI: watch the count climb, watch the place name itself.
    if quest.locked then
        self:drawKeys(quest, x, y, w)
        return
    end

    local rewards = tostring(quest.rewardGold) .. " gold"
    if quest.rewardRep > 0 then rewards = rewards .. ", " .. quest.rewardRep .. " rep" end
    if quest.rewardPrestige > 0 then rewards = rewards .. ", " .. quest.rewardPrestige .. " prestige" end
    love.graphics.setColor(0.7, 0.78, 0.7)
    love.graphics.printf("Reward: " .. rewards, x, y + 190, w, "left")
end

-- The locked-quest pane: how many keys are held, and the location fragments the generals already
-- killed gave up. Each hint is one dead sin; seven of them name the place.
function QuestBoard:drawKeys(quest, x, y, w)
    love.graphics.setColor(0.85, 0.6, 0.55)
    love.graphics.printf(string.format("%d of %d keys", quest.keysHeld, quest.keysNeeded),
        x, y + 190, w, "left")

    local hints = quest.hints or {}
    if #hints == 0 then
        love.graphics.setColor(0.5, 0.52, 0.58)
        love.graphics.printf("Sealed. The generals know where.", x, y + 218, w, "left")
        return
    end

    love.graphics.setColor(0.55, 0.58, 0.66)
    love.graphics.printf("Fragments:", x, y + 218, w, "left")
    love.graphics.setColor(0.72, 0.7, 0.62)
    love.graphics.printf(table.concat(hints, "\n"), x, y + 240, w, "left")
end

local function isInsideBox(self, x, y)
    return x >= self.boxX and x <= self.boxX + BOX_W
        and y >= self.boxY and y <= self.boxY + BOX_H
end

function QuestBoard:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.menu:mousemoved(x, y)
end

-- Hand over the close X or any quest row; arrow elsewhere. See ui/cursor.lua.
function QuestBoard:cursorKind(x, y)
    if self.closeButton:contains(x, y) or self.menu:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function QuestBoard:wheelmoved(dx, dy)
    self.menu:wheelmoved(dx, dy)
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
