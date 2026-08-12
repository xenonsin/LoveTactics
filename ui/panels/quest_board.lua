-- Quest Board pop-up panel. Lists the quests the player can start (left column)
-- and shows details for the highlighted quest (right column). The quest list
-- reuses ui/menu.lua for three-input navigation; we read `menu.selected` each
-- frame to drive the detail pane. Starting a quest switches to the game state.
--
--   local panel = QuestBoard.new({ prestige = p.prestige, onClose = fn })

local State = require("states")
local Menu = require("ui.menu")
local Quest = require("models.quest")
local Request = require("models.request") -- the foraging rows under the posted work
local Calendar = require("models.calendar") -- the last day belongs to the Gate alone
local Player = require("models.player")
local Growth = require("models.growth")
local Item = require("models.item")
local ItemTooltip = require("ui.item_tooltip")
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

-- The reward relics read as ITEM ICONS rather than a comma-joined list of names: a relic is the
-- reason to take one quest over another, and a name alone says nothing about what it does. Each
-- plate opens the game's standard item tooltip on hover (mouse) or on focus (keyboard/gamepad,
-- left/right along the row), so the full stat block is one gesture away without leaving the board.
local ICON, ICON_GAP = 46, 8

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
    -- The relic plates belong to whichever quest was selected; a rebuilt board has none until the
    -- detail pane draws again.
    self.relicRects, self.relicFocus = nil, nil

    -- Build the quest list. Selecting a quest starts it: the game state generates the overworld map
    -- from the quest's `map` params, using the player's prestige to pick dynamic encounters (see
    -- states/game.lua, models/encounter.lua).
    --
    -- A `locked` quest is on the board but not startable: the Gate Below appears the moment you kill
    -- your first general and counts your keys until you have all seven (see Quest.available). Menu has
    -- no notion of a disabled row -- activation just calls `action` -- so the guard lives here, and it
    -- is the one thing standing between a one-key player and the Demon Lord.
    local items = {}

    -- Nothing heads this list but the houses' own posted work, which is what a board was always for. A
    -- "Descend" row lived here for a while and then became a Gate panel that owned this board as a
    -- child; the descent is its own game mode now, entered from the title screen (states/descent.lua),
    -- and the campaign's board answers to nothing but the campaign.
    for _, quest in ipairs(self.quests) do
        items[#items + 1] = {
            label = quest.locked and (quest.name .. " (Locked)") or quest.name,
            action = function()
                if quest.locked then return end
                -- Straight into the overworld. There is nothing to assemble first: the whole roster
                -- marches, and which of them take the field is chosen per battle in the deployment
                -- phase, over the actual board (docs/deployment.md).
                local function begin()
                    State.switch(require("states.game"), quest, nil, self.player)
                end
                -- An intro scene plays first (over the hub, which stays frozen behind it); once it
                -- concludes we set out. No intro -> straight through.
                if quest.intro then
                    require("models.conversation").play(quest.intro, begin)
                else
                    begin()
                end
            end,
        }
    end

    -- FORAGING, one row per house, under the posted work. A day has to be spendable on something other
    -- than somebody's errand or the calendar has one hand: forty expeditions against ninety-two quests
    -- means constantly choosing which house to advance, and a day you do not want to give to a story is
    -- currently a day you cannot give to anything (models/request.lua).
    --
    -- Below the quests rather than above them, and never selected by default: this is the fallback a
    -- player reaches for, not the campaign. It pays that house's stock and gold, and no standing --
    -- foraging finishes no quest, so it opens no shelf.
    --
    -- Not offered on the LAST DAY. The only thing that day is for is the Gate, and a row that let a
    -- player spend it on ore would be the game quietly hiding its own ending.
    if not Calendar.isFinalDay(self.player) then
        for _, house in ipairs(Request.houses()) do
            items[#items + 1] = {
                label = "Forage for " .. house.name,
                action = function()
                    local quest = Request.quest(house.id)
                    if quest then State.switch(require("states.game"), quest, nil, self.player) end
                end,
            }
        end
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
    -- A new quest brings a new set of relics, so the focus ring cannot survive the move -- index 2 on
    -- the last quest means nothing on this one.
    if self.lastSelected ~= self.menu.selected then
        self.lastSelected = self.menu.selected
        self.relicFocus = nil
    end
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
        and "A: Start    D-pad: Scroll / Relics    B: Close"
        or "Click a quest / Enter: Start    Wheel / PgUp / PgDn: Scroll    Click X / Esc: Close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 34, BOX_W, "center")

    self:drawDebugToggle()
    self.closeButton:draw()

    -- The hovered (or focused) relic's tooltip, last of all, so it floats over everything else. Hung off
    -- the CURSOR, like every other item hover in the game -- a pad/keyboard focus has no cursor to hang
    -- from, so that one anchors on the plate instead. ItemTooltip clamps either to the screen.
    local rect, pointed = self:hoveredRelic()
    if rect and rect.relic.item then
        if pointed then
            ItemTooltip.draw(rect.relic.item, self.mx, self.my)
        else
            ItemTooltip.draw(rect.relic.item, rect.x + rect.w, rect.y - 12)
        end
    end

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
        self.relicRects = nil
        self:drawKeys(quest, x, y, w)
        return
    end

    cy = cy + 6

    -- Gold only, on this line. Prestige is a flat 1 for every quest on the board
    -- (Quest.PRESTIGE_PER_QUEST), and a figure identical on every card is not information -- it was
    -- worth printing when quests paid 1, 2 or 3 and the card was where you learned which.
    row("Reward: " .. tostring(quest.rewardGold) .. " gold", Theme.ink)

    -- THE RELIC, AND ONLY THE RELIC. `rewardCharacter` is deliberately NOT read here: the board is
    -- read before the quest, and printing "Clem joins your party" hands you the ending of a scene
    -- whose whole job is to earn her. A companion arrives through the outro and the join banner
    -- (Conversation.pendingJoins), which is where the surprise belongs -- the board promises gear.
    local relics = self:rewardRelics(quest)
    if #relics > 0 then
        row(#relics == 1 and "Relic" or "Relics", Theme.muted, 2)
        cy = cy + self:drawRelicIcons(relics, x, cy, w) + 6
    else
        self.relicRects = nil
    end
end

-- The items behind `rewardItems`, instantiated so the hover tooltip can quote the real thing (its
-- stats, its ability, its flavour) rather than a name. Memoized per quest: instantiation copies the
-- whole blueprint, and the detail pane rebuilds every frame. An id that has been renamed out of the
-- data yields `{ id = id }` with no item, so a stale reference reads as an odd plate rather than
-- crashing Item.instantiate.
function QuestBoard:rewardRelics(quest)
    self.relicCache = self.relicCache or {}
    local cached = self.relicCache[quest]
    if cached then return cached end

    local relics = {}
    for _, id in ipairs(quest.rewardItems or {}) do
        relics[#relics + 1] = { id = id, item = Item.defs[id] and Item.instantiate(id) or nil }
    end
    self.relicCache[quest] = relics
    return relics
end

-- Draw the relic plates in a row at (x, cy), wrapping into further rows if a quest ever grants more
-- than the column fits. Records each plate's rect in self.relicRects so the hover test and the
-- keyboard/gamepad focus ring both read the same geometry. Returns the height consumed.
function QuestBoard:drawRelicIcons(relics, x, cy, w)
    local perRow = math.max(1, math.floor((w + ICON_GAP) / (ICON + ICON_GAP)))
    local rects = {}

    for i, relic in ipairs(relics) do
        local col, rowIndex = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local ix = x + col * (ICON + ICON_GAP)
        local iy = cy + rowIndex * (ICON + ICON_GAP)
        rects[i] = { x = ix, y = iy, w = ICON, h = ICON, relic = relic }

        local focused = (self.relicFocus == i) or self:relicHit(i)
        Theme.set(Theme.panel2)
        love.graphics.rectangle("fill", ix, iy, ICON, ICON, 6, 6)
        if focused then Theme.set(Theme.accentAmber) else Theme.set(Theme.frame, 0.7) end
        love.graphics.setLineWidth(focused and 2 or 1)
        love.graphics.rectangle("line", ix, iy, ICON, ICON, 6, 6)
        love.graphics.setLineWidth(1)

        -- Art when the item has it, its initial on a plate when it does not -- the same fallback the
        -- inventory grid draws, so a relic with no sprite yet still reads as a thing you can hover.
        local item = relic.item
        local sprite = item and item.sprite
        local label = (item and item.name) or relic.id
        if type(sprite) == "userdata" then
            local iw, ih = sprite:getDimensions()
            local scale = math.min((ICON - 10) / iw, (ICON - 10) / ih)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(sprite, ix + ICON / 2, iy + ICON / 2, 0, scale, scale, iw / 2, ih / 2)
        else
            love.graphics.setFont(self.headFont)
            Theme.set(Theme.ink)
            love.graphics.printf(label:sub(1, 1):upper(), ix,
                iy + (ICON - self.headFont:getHeight()) / 2, ICON, "center")
        end
    end

    self.relicRects = rects
    local rows = math.ceil(#relics / perRow)
    return rows * ICON + (rows - 1) * ICON_GAP
end

-- True when the mouse is over relic plate `i`. Nil-safe both ways: the pointer may not have moved
-- since the panel opened, and the pane may not have drawn any plates yet.
function QuestBoard:relicHit(i)
    local r = self.relicRects and self.relicRects[i]
    if not (r and self.mx) then return false end
    return self.mx >= r.x and self.mx <= r.x + r.w and self.my >= r.y and self.my <= r.y + r.h
end

-- The plate the pointer is over, or the one the keyboard/gamepad focus ring sits on, plus whether it
-- was the POINTER that found it (the caller hangs the tooltip off the cursor if so, off the plate if
-- not). The pointer wins: if it is over a plate, that is the one the player is asking about.
function QuestBoard:hoveredRelic()
    for i in ipairs(self.relicRects or {}) do
        if self:relicHit(i) then return self.relicRects[i], true end
    end
    local focused = self.relicFocus and self.relicRects and self.relicRects[self.relicFocus]
    return focused, false
end

-- Step the focus ring along the relic row (keyboard/gamepad, which cannot hover). Wraps, and stays
-- nil-safe on a quest granting none -- left/right then falls through to the menu as before.
function QuestBoard:moveRelicFocus(dir)
    local n = self.relicRects and #self.relicRects or 0
    if n == 0 then return false end
    local i = (self.relicFocus or 0) + dir
    if i < 1 then i = n elseif i > n then i = 1 end
    self.relicFocus = i
    return true
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
    self.mx, self.my = x, y
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
    -- Left/right walks the relic plates -- the only way a player without a mouse can read a reward's
    -- tooltip. It falls through to the menu when the quest grants no relic, where the pair is a no-op
    -- anyway (a quest row carries no `adjust`).
    elseif (key == "left" or key == "a") and self:moveRelicFocus(-1) then
    elseif (key == "right" or key == "d") and self:moveRelicFocus(1) then
    else
        self.menu:keypressed(key)
    end
end

function QuestBoard:gamepadpressed(joystick, button)
    if button == "b" then
        self:close()
    elseif button == "dpleft" and self:moveRelicFocus(-1) then
    elseif button == "dpright" and self:moveRelicFocus(1) then
    else
        self.menu:gamepadpressed(joystick, button)
    end
end

return QuestBoard
