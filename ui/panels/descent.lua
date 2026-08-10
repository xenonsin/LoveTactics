-- THE GATE. The city's front door onto the descent, and the between-run screen the whole loop now
-- turns on: what you have already done, what it is still costing you, and the one button that starts
-- the next run.
--
--   local panel = Descent.new({ player = p, prestige = p.prestige, onClose = fn })
--
-- WHY THIS REPLACED THE QUEST BOARD'S DOOR RATHER THAN TAKING ONE OF ITS OWN. The city grid is full --
-- eleven cards plus two narrow extras, all occupied (data/buildings/*.lua's own header lays it out) --
-- so a fourteenth building would have had to break the grid the comment asks new content to keep to.
-- The board's slot is also the right one on its merits: it is the first card in the city, and starting
-- a run is what a player comes to that corner of the map to do.
--
-- The campaign is NOT deleted for it. The seven authored quest lines are still the only story content
-- in the game until the descent carries them (a later stage folds them into the floors), so the board
-- lives on as a nested panel this one opens -- the same way ui/panels/cafe.lua owns its confirmation
-- Choice. Deleting a working door to satisfy a plan step whose replacement is not built yet would cost
-- the player seven quest lines and buy nothing.

local State = require("states")
local Menu = require("ui.menu")
local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")
local Descent = require("models.descent")
local Vendor = require("models.vendor")
local Wound = require("models.wound")
local Quest = require("models.quest")

local Gate = {}
Gate.__index = Gate

local BOX_W, BOX_H = 760, 560
local LIST_TOP = 150
local ROW_H, ROW_SPACING, MAX_VISIBLE = 44, 8, 4

local function printWrapped(text, font, x, y, w)
    love.graphics.setFont(font)
    local _, lines = font:getWrap(text, w)
    love.graphics.printf(text, x, y, w, "left")
    return #lines * font:getHeight()
end

function Gate.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Gate)
    self.player = opts.player
    self.prestige = opts.prestige or 1
    self.onClose = opts.onClose
    self.titleFont = Theme.display(30)
    self.headFont = Theme.display(20)
    self.bodyFont = Theme.body(16)
    self.smallFont = Theme.body(13)

    self.boxX = (Scale.WIDTH - BOX_W) / 2
    self.boxY = (Scale.HEIGHT - BOX_H) / 2
    self.listLeft = self.boxX + 28
    self.listW = 320
    self.listTop = self.boxY + LIST_TOP
    self.detailX = self.boxX + 380
    self.detailY = self.boxY + LIST_TOP - 8
    self.detailW = BOX_W - 408

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    self:refresh()
    return self
end

-- THE RESUME IS THE FIRST ROW WHEN THERE IS ONE. A player who quit on floor four and came back is not
-- choosing between a new run and that one -- they are choosing whether to go back down -- so the row
-- that continues has to be the one under the cursor when the panel opens.
function Gate:refresh()
    local selected = self.menu and self.menu.selected or 1
    self.rows = {}
    local resumable = self.player and self.player.activeRun and self.player.activeRun.descent

    if resumable then
        self.rows[#self.rows + 1] = {
            kind = "resume",
            label = "Go back down  -  floor " .. Descent.depth(resumable),
            detail = "The company is still standing on floor " .. Descent.depth(resumable) ..
                ", and everything it is carrying is still at stake. Nothing was banked when you " ..
                "stopped playing; nothing was lost either.",
        }
    end
    self.rows[#self.rows + 1] = {
        kind = "descend",
        label = resumable and "Abandon it and start over" or "Descend",
        detail = resumable
            and "Give up the run below and open a fresh gate. Everything that company was carrying " ..
                "goes back to where it stood before it walked in."
            or "Seven circles, dealt in a different order every time, and the Hollow Crown under " ..
                "them. What you are carrying is only yours once you climb out -- or once it is dead.",
    }
    self.rows[#self.rows + 1] = {
        kind = "contracts",
        label = "Contracts",
        detail = "The board in the corner. The houses still post work of their own, and their " ..
            "stories are told there rather than down the stair.",
    }

    local items = {}
    for i, row in ipairs(self.rows) do
        items[#items + 1] = { label = row.label, action = function() self:choose(self.rows[i]) end }
    end
    self.menu = Menu.new(items, {
        buttonWidth = self.listW, buttonHeight = ROW_H, spacing = ROW_SPACING,
        startY = self.listTop, centerX = self.listLeft + self.listW / 2,
        font = self.bodyFont, maxVisible = MAX_VISIBLE,
    })
    self.menu.selected = math.min(selected, #items)
    self.menu:layout()
end

function Gate:selectedRow() return self.rows and self.menu and self.rows[self.menu.selected] end
function Gate:close() if self.onClose then self.onClose() end end

function Gate:choose(row)
    if not row then return end
    if row.kind == "contracts" then
        -- The board, owned as a child panel. It keeps its own launcher: until the authored lines run
        -- as floors, this is still the only way into seven quest lines' worth of story.
        self.board = require("ui.panels.quest_board").new({
            player = self.player, prestige = self.prestige,
            onClose = function() self.board = nil end,
        })
        -- Laid out here, explicitly. A top-level panel gets its first layout from the hub's own update
        -- before anything draws; a panel opened mid-frame by another panel has no such guarantee, and
        -- an unlaid Menu draws NOTHING (Menu:draw skips any item without an x) -- so the board came up
        -- with a working detail column beside an empty list. Idempotent, so the update that follows
        -- changes nothing.
        if self.board.menu then self.board.menu:layout() end
        return
    end

    local run = self.player.activeRun and self.player.activeRun.descent
    if row.kind == "resume" and run then
        -- Straight back onto the floor they left. The run carries its own rollback point, its unbanked
        -- standing and its depth, so nothing has to be rebuilt here.
        State.switch(require("states.game"),
            Descent.floorQuest(run, self.player), self.prestige, self.player)
        return
    end

    -- A fresh gate. Abandoning a run in progress is left to states/game.lua's own rollback the next
    -- time it runs -- this only stops pointing at it, and the entry snapshot on the old run is what
    -- would have put the company back anyway.
    self.player.activeRun = nil
    local fresh = Descent.new(self.player)
    State.switch(require("states.game"),
        Descent.floorQuest(fresh, self.player), self.prestige, self.player)
end

function Gate:update(dt)
    if self.board then
        if self.board.update then self.board:update(dt) end
        return
    end
    if self.menu.update then self.menu:update(dt) end
end

-- WHAT THE COMPANY HAS TO SHOW FOR ITSELF. Three readings, in the order a player asks them: how deep
-- have I ever got, who is still hurt, and which houses am I in good with. The last two are the two
-- meters the descent runs on, so they belong on the screen that decides whether to run it again.
function Gate:drawStanding()
    local x, y, w = self.detailX, self.detailY, self.detailW
    local row = self:selectedRow()

    Theme.set(Theme.accentAmber)
    local ty = y + printWrapped(row and row.label or "", self.headFont, x, y, w) + 6
    Theme.set(Theme.ink)
    ty = ty + printWrapped(row and row.detail or "", self.smallFont, x, ty, w) + 16

    local deepest = (self.player and self.player.deepest) or 0
    Theme.set(Theme.muted)
    ty = ty + printWrapped("Deepest floor", self.smallFont, x, ty, w) + 2
    Theme.set(Theme.accentAmber)
    ty = ty + printWrapped(deepest > 0 and tostring(deepest) or "none yet -- the company has never gone down",
        self.bodyFont, x, ty, w) + 14

    -- The wounded, named. This is the number a player is really weighing when they decide whether to
    -- descend again, and the Cafe is where it gets paid off (models/wound.lua).
    local hurt = Wound.wounded(self.player)
    Theme.set(Theme.muted)
    ty = ty + printWrapped("Wounded", self.smallFont, x, ty, w) + 2
    if #hurt == 0 then
        Theme.set(Theme.ink)
        ty = ty + printWrapped("nobody -- the company is whole", self.bodyFont, x, ty, w) + 14
    else
        for _, entry in ipairs(hurt) do
            love.graphics.setColor(0.90, 0.55, 0.52)
            ty = ty + printWrapped((entry.char.name or entry.char.id) .. "  -  recovers to only " ..
                math.floor(Wound.healShare(self.player, entry.char.id) * 100) .. "%",
                self.smallFont, x + 8, ty, w - 8) + 2
        end
        ty = ty + 12
    end

    -- Standing per circle, in the canonical order of the sins rather than by how much you have -- the
    -- list is a map of the seven, and a leaderboard would hide which one you have never been down.
    --
    -- ANCHORED FROM THE BOTTOM, not flowed after the block above it. It is a fixed seven rows and the
    -- things above it are not: a wounded company or a longer row description pushed it straight through
    -- the footer, and every fix that shortened the prose would have broken again the next time somebody
    -- lengthened it. Laid out from the one edge that cannot move instead.
    local lineH = self.smallFont:getHeight() + 1
    local top = self.boxY + BOX_H - 52 - (#Descent.SINS + 1) * lineH
    Theme.set(Theme.muted)
    love.graphics.setFont(self.smallFont)
    love.graphics.print("Standing", x, top)
    for i, sin in ipairs(Descent.SINS) do
        local n = Quest.sponsorProgress(self.player, sin.vendor)
        local house = (Vendor.get(sin.vendor) or {}).name or sin.vendor
        Theme.set(n > 0 and Theme.ink or Theme.muted)
        love.graphics.print(sin.name .. "  -  " .. house .. "  " .. n, x + 8, top + i * lineH)
    end
end

function Gate:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Gate", self.boxX, self.boxY + 24, BOX_W, "center")
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf("No target and no contract. Seven circles, and the thing under them.",
        self.boxX + 40, self.boxY + 66, BOX_W - 80, "center")

    self.menu:draw()
    self:drawStanding()

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    local hint = InputMode.isGamepad() and "A: choose    B: close"
        or "Click / Enter: choose    Click X / Esc: close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")
    self.closeButton:draw()

    -- The board, when it is open, draws OVER all of this -- it is a modal the Gate is holding, not a
    -- column of it.
    if self.board then self.board:draw() end
end

-- Input: the board owns everything while it is open, exactly as the Cafe's confirmation does.
function Gate:mousemoved(x, y)
    if self.board then return self.board:mousemoved(x, y) end
    self.menu:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
end

function Gate:cursorKind(x, y)
    if self.board then return self.board.cursorKind and self.board:cursorKind(x, y) or "arrow" end
    if self.closeButton:contains(x, y) then return "hand" end
    return self.menu:mouseOverItem(x, y) and "hand" or "arrow"
end

function Gate:mousepressed(x, y, button)
    if self.board then return self.board:mousepressed(x, y, button) end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    self.menu:mousepressed(x, y, button)
end

function Gate:wheelmoved(dx, dy)
    if self.board and self.board.wheelmoved then return self.board:wheelmoved(dx, dy) end
    if self.menu.wheelmoved then self.menu:wheelmoved(dx, dy) end
end

function Gate:keypressed(key)
    if self.board then return self.board:keypressed(key) end
    if key == "escape" then return self:close() end
    self.menu:keypressed(key)
end

function Gate:gamepadpressed(joystick, button)
    if self.board then return self.board:gamepadpressed(joystick, button) end
    if button == "b" then return self:close() end
    self.menu:gamepadpressed(joystick, button)
end

return Gate
