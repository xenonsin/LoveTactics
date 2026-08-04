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
local Discipline = require("models.discipline")
local Growth = require("models.growth")
local Item = require("models.item")
local Character = require("models.character")
local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")
local Debug = require("models.debug")
local Theme = require("ui.theme")

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
    self.titleFont = Theme.display(30)
    self.headFont = Theme.display(20)
    self.bodyFont = Theme.body(16)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.prestige = opts.prestige or 1
    self.player = opts.player -- carried into the game state so the overworld sees the party

    -- Debug "show all quests" toggle: a development-only button in the footer that drops every gate
    -- (models/quest.lua) so a line can be run without progressing to it naturally. Only laid out and
    -- only drawn when Debug.enabled, so a release build never shows it.
    if Debug.enabled then
        self.debugRect = { x = self.boxX + 16, y = self.boxY + BOX_H - 76, w = 220, h = 26 }
    end

    self:rebuild()

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- (Re)load the board and its menu. Split out from `new` so the debug toggle can rebuild in place
-- when it flips a gate -- the quest list and the left-column menu are both derived from
-- Quest.available, so both are rebuilt together.
--
-- The board is filtered by the whole player, not just prestige: finished quests drop off it, and a
-- sponsor's later quests only appear once you have finished enough of that sponsor's earlier ones.
function QuestBoard:rebuild()
    self.quests = Quest.available(self.player)

    -- Build the quest list. Selecting a quest starts it: the game state generates the overworld map
    -- from the quest's `map` params, using the player's prestige to pick dynamic encounters (see
    -- states/game.lua, models/encounter.lua).
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
                local function begin()
                    State.switch(require("states.party_select"), quest, self.prestige, self.player)
                end
                -- An intro scene plays first (over the hub, which stays frozen behind it); once it
                -- concludes we proceed into party select. No intro -> straight through.
                if quest.intro then
                    require("models.conversation").play(quest.intro, begin)
                else
                    begin()
                end
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
end

-- Flip the debug gate and reload the board so the newly (un)gated quests appear at once.
function QuestBoard:toggleDebug()
    if not Debug.enabled then return end
    Debug.showAllQuests = not Debug.showAllQuests
    self:rebuild()
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
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    -- Title.
    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Quest Board", self.boxX, self.boxY + 24, BOX_W, "center")

    if #self.quests == 0 then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf("No quests available.", self.boxX, self.boxY + BOX_H / 2,
            BOX_W, "center")
    else
        -- Left: the quest list.
        self.menu:draw()

        -- Right: details for the highlighted quest.
        self:drawDetail()
    end

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "A: Start    D-pad: Scroll    B: Close"
        or "Click a quest / Enter: Start    Wheel / PgUp / PgDn: Scroll    Click X / Esc: Close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self:drawDebugToggle()
    self.closeButton:draw()

    love.graphics.setColor(1, 1, 1)
end

-- The development-only "show all quests" pill in the bottom-left corner. Lit when the gate is
-- dropped. Drawn (and hit-tested) only when Debug.enabled, so a release build never shows it.
function QuestBoard:drawDebugToggle()
    local r = self.debugRect
    if not r then return end
    local on = Debug.showAllQuests
    love.graphics.setColor(on and 0.28 or 0.16, on and 0.22 or 0.16, on and 0.14 or 0.2)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setColor(on and 0.95 or 0.4, on and 0.7 or 0.42, on and 0.35 or 0.5)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(on and 0.98 or 0.7, on and 0.85 or 0.72, on and 0.55 or 0.78)
    love.graphics.printf("Debug: All Quests " .. (on and "ON" or "OFF") .. "  [F1]",
        r.x, r.y + (r.h - self.bodyFont:getHeight()) / 2, r.w, "center")
end

function QuestBoard:debugHit(x, y)
    local r = self.debugRect
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function QuestBoard:drawDetail()
    local quest = self.quests[self.menu.selected]
    if not quest then return end

    local x = self.boxX + BOX_W * 0.50
    local w = BOX_W * 0.44
    local y = self.boxY + LIST_TOP - 12

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.ink)
    love.graphics.printf(quest.name, x, y, w, "left")

    -- The sponsor is the reason to pick one quest over another, so it reads in the accent
    -- color directly under the name, with the player's standing beside it.
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(quest.sponsorName, x, y + 30, w, "left")

    if quest.sponsor then
        local done = Quest.sponsorProgress(self.player, quest.sponsor)
        local quests = done == 1 and "quest" or "quests"
        Theme.set(Theme.muted)
        love.graphics.printf(done .. " " .. quests .. " completed here", x, y + 50, w, "left")
    end

    Theme.set(Theme.ink)
    love.graphics.printf(quest.description, x, y + 78, w, "left")

    -- Everything below the description stacks, because it varies: a quest may promise a companion, a
    -- relic, both or neither, and the pane used to draw two fixed lines and stop. `row` keeps the
    -- offsets in one place so adding a line cannot silently overlap the next one.
    local cy = y + 162
    local function row(text, colour, gap)
        Theme.set(colour or Theme.muted)
        love.graphics.printf(text, x, cy, w, "left")
        -- Advance by what the text ACTUALLY occupied, not by a fixed step. These lines wrap -- the
        -- floor warning names two levels and runs to two lines in the pane's width -- and a fixed
        -- step drew the next row straight through it.
        local _, wrapped = self.bodyFont:getWrap(text, w)
        local lines = math.max(1, #wrapped)
        cy = cy + lines * self.bodyFont:getHeight() + (gap or 4)
    end

    -- WHAT THIS LINE LEADS TO. A house teaches a class, and its line is what opens that class's paths
    -- (Discipline.subclassesOf). Naming them is the whole answer to "why commit to this house rather
    -- than spread" -- the shop's section headers have said it for a while and the board, where the
    -- choice is actually made, said nothing at all.
    local paths = self:pathsFor(quest.sponsor)
    if paths then row("Path: " .. paths, Theme.accentAmber) end

    row("Difficulty: " .. tostring(quest.difficulty))

    -- THE DEPTH FLOOR, AS A WARNING RATHER THAN AN AMBUSH. A line can be run alone all the way down;
    -- what holds a player back is how hard it gets (Quest.SLOT_FLOOR). That is a soft lock only if it
    -- can be seen coming -- otherwise it is an unfair fight -- so the floor reads here, and reads RED
    -- when the company is under it.
    if quest.floorLevel then
        local ours = Growth.levelForPrestige(self.player and self.player.prestige or 1)
        if ours < quest.floorLevel then
            row(string.format("Enemies here fight at level %d or better -- your company is %d",
                quest.floorLevel, ours), Theme.accentWeapon)
        else
            row(string.format("Enemies here fight at level %d or better", quest.floorLevel))
        end
    end

    -- A locked quest has no reward to offer yet, only a tally and whatever the dead have given up.
    -- This is the whole endgame UI: watch the count climb, watch the place name itself.
    if quest.locked then
        self:drawKeys(quest, x, y, w)
        return
    end

    cy = cy + 6

    -- Gold only, on this line. Prestige is a flat 1 for every quest on the board
    -- (Quest.PRESTIGE_PER_QUEST), and a figure identical on every card is not information -- it was
    -- worth printing when quests paid 1, 2 or 3 and the card was where you learned which.
    row("Reward: " .. tostring(quest.rewardGold) .. " gold", Theme.ink)

    -- A RELIC, AND A COMPANION. Quest.available has carried both of these onto every board entry from
    -- the beginning -- rewardCharacter with a comment saying a companion is the strongest reward in the
    -- game and must not arrive as a surprise -- and no screen has ever read either one.
    local items = self:rewardItemNames(quest)
    if items then row("Relic: " .. items, Theme.ink) end

    local joins = self:rewardCharacterName(quest)
    if joins then row(joins .. " joins your party", Theme.accentAmber) end
end

-- The disciplines a sponsor's line opens, as a comma-joined display string, or nil for an unsponsored
-- quest or a house whose class teaches none.
function QuestBoard:pathsFor(sponsor)
    local def = sponsor and Vendor.get(sponsor)
    if not (def and def.class) then return nil end

    local names = {}
    for _, id in ipairs(Discipline.subclassesOf(def.class)) do
        names[#names + 1] = Discipline.displayName(id)
    end
    if #names == 0 then return nil end

    table.sort(names)
    return table.concat(names, ", ")
end

-- The names behind `rewardItems`, or nil when the quest grants none. Falls back to the raw id for an
-- item that has been renamed out of the data, so a stale reference reads as odd rather than vanishing.
function QuestBoard:rewardItemNames(quest)
    local ids = quest.rewardItems
    if not (ids and #ids > 0) then return nil end

    local names = {}
    for _, id in ipairs(ids) do
        local def = Item.defs[id]
        names[#names + 1] = (def and def.name) or id
    end
    return table.concat(names, ", ")
end

-- The display name behind `rewardCharacter`, or nil when the quest recruits nobody.
function QuestBoard:rewardCharacterName(quest)
    local id = quest.rewardCharacter
    if not id then return nil end
    local def = Character.defs[id]
    return (def and def.name) or id
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
    if self.closeButton:contains(x, y) or self.menu:mouseOverItem(x, y) or self:debugHit(x, y) then
        return "hand"
    end
    return "arrow"
end

function QuestBoard:wheelmoved(dx, dy)
    self.menu:wheelmoved(dx, dy)
end

function QuestBoard:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then
        self:close()
    elseif self:debugHit(x, y) then
        self:toggleDebug()
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
    elseif key == "f1" then
        self:toggleDebug()
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
