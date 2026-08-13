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
local Biome = require("models.biome") -- a ground's display name for its tab
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

-- The tab row sits between the title and the list: one plate per ground the company can travel to
-- this morning. The list drops to five rows to pay for it.
local TAB_TOP, TAB_H, TAB_GAP = 64, 40, 6
local LIST_TOP = 116
local ROW_H, ROW_SPACING, MAX_VISIBLE = 44, 8, 5

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
    -- The tab countdown sits under the ground's name on a 40px plate, so it gets its own smaller
    -- face rather than a scaled one -- printed text is never scaled in this project, it blurs.
    self.capFont = Theme.body(12)

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
-- THE GROUNDS ON OFFER THIS MORNING, each with the work that can be reached from it. Quest.board does
-- the season-table half (models/biome_window.lua); this adds the panel's own foraging rows and then
-- drops any ground left holding nothing.
--
-- A GROUND WITH NOTHING IN IT DRAWS NO TAB. Not a greyed plate -- a control appears where it can be
-- used, and a tab you can travel to and find empty is a control that does nothing. It also keeps the
-- debut clean: on the first morning four grounds are open, the player has finished no quest so no
-- house is posting errands, and exactly one tab is drawn with exactly one quest under it. The tutorial
-- goes on teaching by being the only thing there.
function QuestBoard:buildGrounds()
    local board = Quest.board(self.player)
    -- Foraging is a fallback, not the campaign, and it is not offered on the first morning (see
    -- above) or on the last -- the only thing the last day is for is the Gate, and a row that let a
    -- player spend it on ore would be the game quietly hiding its own ending.
    local forageOk = Player.questsCompleted(self.player) > 0 and not Calendar.isFinalDay(self.player)

    self.grounds = {}
    for _, ground in ipairs(board.grounds) do
        local def = Biome.get(ground.id)
        ground.name = def and def.name or ground.id
        ground.forage = forageOk and Request.housesIn(ground.id) or {}
        -- `startable` rather than #quests: a ground carrying only the Gate's locked countdown has
        -- nothing you can actually do on it, and a tab you can travel to and find nothing at is a
        -- control that does nothing.
        if (ground.startable or #ground.quests) > 0 or #ground.forage > 0 then
            self.grounds[#self.grounds + 1] = ground
        end
    end

    -- Keep the player standing where they were if that ground is still on offer -- rebuild() is called
    -- by the debug toggle mid-session, and having the board jump back to the first tab under you is
    -- the kind of small betrayal that makes a panel feel broken.
    -- Failing that, open on the first ground with POSTED WORK on it rather than on whichever sorts
    -- first. Foraging is the fallback a player reaches for, not the campaign, and a board that opens
    -- looking at a ground offering nothing but ore has led with the fallback.
    local wanted = self.groundId
    self.ground = 1
    for i, ground in ipairs(self.grounds) do
        if (ground.startable or #ground.quests) > 0 then
            self.ground = i
            break
        end
    end
    for i, ground in ipairs(self.grounds) do
        if ground.id == wanted then self.ground = i end
    end
    self.groundId = self.grounds[self.ground] and self.grounds[self.ground].id
end

function QuestBoard:rebuild()
    self:buildGrounds()
    -- The quests of the ground currently being looked at. The detail pane indexes this by menu row,
    -- so it must stay in step with the menu built below -- quests first, foraging after.
    local here = self.grounds[self.ground]
    self.quests = here and here.quests or {}
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
                    -- The ground the player travelled to is what the run is fought on. Quest.start
                    -- collapses the quest's set of possible grounds down to this one, which is the
                    -- single `map.biome` everything downstream has always read.
                    State.switch(require("states.game"),
                        Quest.start(quest, self.groundId), nil, self.player)
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
    -- NOT ON THE FIRST MORNING. The debut on the sand is the tutorial, and the tutorial teaches by
    -- being the only thing on the board -- a newcomer who opens this panel must see one row and know
    -- what to press. Seven foraging offers beside it is a menu, and a menu is not a lesson.
    --
    -- Gated on having finished ANY quest rather than on the debut's id: the debut is the only thing
    -- available at standing 1, so the two are the same test today, and the generic one cannot be
    -- silently reopened by renaming or renumbering that quest. It also reads as the truer rule --
    -- the houses do not post errands to somebody who has never worked for them.
    --
    -- Not offered on the LAST DAY either. The only thing that day is for is the Gate, and a row that
    -- let a player spend it on ore would be the game quietly hiding its own ending.
    -- Only the houses that work THIS ground (Request.housesIn). The seven-row block that used to sit
    -- here regardless is what a destination costs: a house forages where its own quests are, so
    -- travelling to the tundra offers you the Bastion's ore and nobody else's.
    for _, house in ipairs(here and here.forage or {}) do
        items[#items + 1] = {
            label = "Forage for " .. house.name,
            action = function()
                local quest = Request.quest(house.id, { biome = self.groundId })
                if quest then State.switch(require("states.game"), quest, nil, self.player) end
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

    self:drawTabs()

    if #self.grounds == 0 then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf("Nowhere to go today.", self.boxX, self.boxY + BOX_H / 2,
            BOX_W, "center")
    else
        -- Left: the quest list for the ground being looked at.
        self.menu:draw()

        -- Right: details for the highlighted quest.
        if #self.quests > 0 then self:drawDetail() end
    end

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "A: Start    LB/RB: Travel    D-pad: Scroll / Relics    B: Close"
        or "Click a quest / Enter: Start    Q/E: Travel    Wheel: Scroll    Click X / Esc: Close"
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

-- THE TAB ROW: where the company can go this morning, and how long each of them stays open.
--
-- The countdown is the whole point of the panel now. A ground with sixteen days left is a shelf you
-- can come back to; one with two is a decision being forced, and the difference has to be readable
-- without opening anything. It says what the number is OF -- "4 days left", never a bare 4 -- because
-- a figure whose unit the player has to infer is a figure they will read wrong once and stop trusting.
--
-- Plates are laid out over the grounds that are actually on offer (buildGrounds), so the row is one
-- plate wide on the first morning and four in the thick of the campaign.
function QuestBoard:drawTabs()
    self.tabRects = {}
    local n = #self.grounds
    if n == 0 then return end

    local inset = 16
    local w = (BOX_W - inset * 2 - TAB_GAP * (n - 1)) / n
    love.graphics.setFont(self.bodyFont)

    for i, ground in ipairs(self.grounds) do
        local x = self.boxX + inset + (i - 1) * (w + TAB_GAP)
        local y = self.boxY + TAB_TOP
        self.tabRects[i] = { x = x, y = y, w = w, h = TAB_H }

        local here = (i == self.ground)
        local hovered = self:tabHit(i)
        Theme.set(here and Theme.panel2 or Theme.panel)
        love.graphics.rectangle("fill", x, y, w, TAB_H, 5, 5)
        if here then Theme.set(Theme.accentAmber)
        elseif hovered then Theme.set(Theme.cursor)
        else Theme.set(Theme.frame, 0.7) end
        love.graphics.setLineWidth(here and 2 or 1)
        love.graphics.rectangle("line", x, y, w, TAB_H, 5, 5)
        love.graphics.setLineWidth(1)

        love.graphics.setFont(self.bodyFont)
        Theme.set(here and Theme.ink or Theme.muted)
        love.graphics.printf(Theme.ellipsize(ground.name, self.bodyFont, w - 10),
            x, y + 3, w, "center")

        -- The countdown reads RED on the last two mornings: at that point it is not information about
        -- the ground any more, it is a deadline on everything filed under it.
        local left = ground.daysLeft
        if left then
            love.graphics.setFont(self.capFont)
            Theme.set(left <= 2 and Theme.accentWeapon or Theme.muted)
            love.graphics.printf(left == 1 and "last day" or (left .. " days left"),
                x, y + 23, w, "center")
        end
    end
end

function QuestBoard:tabHit(i)
    local r = self.tabRects and self.tabRects[i]
    if not (r and self.mx) then return false end
    return self.mx >= r.x and self.mx <= r.x + r.w and self.my >= r.y and self.my <= r.y + r.h
end

-- Travel to another ground. Wraps, and rebuilds the list under it -- the menu, the detail pane and
-- the relic plates are all derived from the selected ground, so they go together.
function QuestBoard:travel(dir)
    local n = #self.grounds
    if n <= 1 then return false end
    local i = self.ground + dir
    if i < 1 then i = n elseif i > n then i = 1 end
    self:selectGround(i)
    return true
end

function QuestBoard:selectGround(i)
    if not self.grounds[i] or i == self.ground then return end
    self.ground = i
    self.groundId = self.grounds[i].id
    self:rebuild()
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

-- The tab index under (x, y), or nil. Takes explicit coordinates rather than reading self.mx, because
-- a click can land on a frame where the pointer has not moved since the panel opened.
function QuestBoard:tabAt(x, y)
    for i, r in ipairs(self.tabRects or {}) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    return nil
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
    if self.closeButton:contains(x, y) or self.menu:mouseOverItem(x, y)
        or self:debugHit(x, y) or self:tabAt(x, y) then
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
    elseif self:tabAt(x, y) then
        self:selectGround(self:tabAt(x, y))
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
    -- Travel. Q/E rather than left/right, which already walk the relic plates -- the only way a player
    -- without a mouse can read a reward's tooltip -- and rather than tab, which the menu may want.
    elseif key == "q" then
        self:travel(-1)
    elseif key == "e" then
        self:travel(1)
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
    -- The shoulders travel between grounds, which leaves the d-pad doing what it already did.
    elseif button == "leftshoulder" then
        self:travel(-1)
    elseif button == "rightshoulder" then
        self:travel(1)
    elseif button == "dpleft" and self:moveRelicFocus(-1) then
    elseif button == "dpright" and self:moveRelicFocus(1) then
    else
        self.menu:gamepadpressed(joystick, button)
    end
end

return QuestBoard
