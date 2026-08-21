-- Quest Board pop-up panel. Lists the GROUNDS the company can travel to today (left column) and what
-- is waiting on the highlighted one (right column). The list reuses ui/menu.lua for three-input
-- navigation; we read `menu.selected` each frame to drive the dossier. Choosing a ground sets out.
--
--   local panel = QuestBoard.new({ player = p, onClose = fn })
--
-- THE ROW IS A PLACE, NOT A PIECE OF WORK, and that is the whole change here.
--
-- The panel used to list quests, with a row of tabs above them naming the grounds each could be run
-- on. A quest was the expedition, the ground was a consequence of it, and picking one meant reading
-- three tabs to find where today's work had landed. It also meant the same locked card -- the Gate
-- Below's countdown, which rides along with every ground because it is a warning rather than a
-- destination -- appeared under every tab, once per heading.
--
-- The day buys a GROUND now (models/quest.lua's Quest.trip). Every piece of work the houses have
-- posted there stands on the board when you arrive, each on its own dead end, ticked off a checklist
-- as you take them (states/game.lua). So the left column is the only choice this panel still has to
-- offer -- where to spend the day -- and the right column exists to argue for one place over another.

local State = require("states")
local Menu = require("ui.menu")
local Quest = require("models.quest")
local Biome = require("models.biome") -- a ground's display name for its row
local Growth = require("models.growth")
local Item = require("models.item")
local ItemTooltip = require("ui.item_tooltip")
local CloseButton = require("ui.close_button")
local VendorIcons = require("ui.vendor_icons") -- the house's mark, learned HERE beside its name
local Scale = require("scale")
local InputMode = require("input_mode")
local Debug = require("models.debug")
local Theme = require("ui.theme")

local QuestBoard = {}
QuestBoard.__index = QuestBoard

-- Panel box geometry, centered in the 1280x720 logical space. The list scrolls (Menu's `maxVisible`)
-- rather than trying to fit -- six rows at a time, with carets marking what is out of sight. Six is
-- comfortably more grounds than the season table ever opens at once, so the carets are a backstop.
local BOX_W, BOX_H = 760, 520
local LIST_TOP = 92
local ROW_H, ROW_SPACING, MAX_VISIBLE = 48, 8, 6

-- The reward relics read as ITEM ICONS rather than a comma-joined list of names: a relic is the
-- reason to take one ground over another, and a name alone says nothing about what it does. Each
-- plate opens the game's standard item tooltip on hover (mouse) or on focus (keyboard/gamepad,
-- left/right along the row), so the full stat block is one gesture away without leaving the board.
local ICON, ICON_GAP = 46, 8

-- The air under a block in the dossier column. One number rather than a per-call literal because the
-- pane MEASURES itself before it draws -- what the gap costs and what the fit assumes it costs have to
-- be the same value or the block runs past the panel's bottom edge.
local GAP = 8

-- The plates are the LAST block in the column and the work is the first, so a ground promising a wall
-- of them must not be able to push the list of work out of the pane -- which is exactly what the debug
-- toggle's thirty-nine-relic tundra did. Two rows is twelve plates: more than any real ground offers
-- (four pieces of work, two relics apiece is the far end), and a ceiling past that point.
local RELIC_ROWS = 2

-- How wide a row of relic plates packs, how tall the block ends up, and how many plates that leaves
-- room for, at column width `w`. Read twice: once by the measure that decides how many lines of prose
-- the work may have, and once by the drawing itself -- so the two can never disagree about how far
-- down the pane the icons reach.
local function relicBlock(n, w)
    local perRow = math.max(1, math.floor((w + ICON_GAP) / (ICON + ICON_GAP)))
    local rows = math.min(math.ceil(n / perRow), RELIC_ROWS)
    return perRow, rows * ICON + (rows - 1) * ICON_GAP, math.min(n, rows * perRow)
end

function QuestBoard.new(opts)
    opts = opts or {}
    local self = setmetatable({}, QuestBoard)
    self.onClose = opts.onClose
    self.titleFont = Theme.display(30)
    self.headFont = Theme.display(20)
    self.bodyFont = Theme.body(16)
    -- The countdown rides under the ground's name on a 48px row, so it gets its own smaller face
    -- rather than a scaled one -- printed text is never scaled in this project, it blurs.
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
-- when it flips a gate.
--
-- THE GROUNDS ON OFFER THIS MORNING, each with the work that can be reached from it. Quest.board does
-- the whole job (models/biome_window.lua for the season table, Quest.available for what is unlocked);
-- this drops any ground left holding nothing.
--
-- A GROUND WITH NO POSTED WORK DRAWS NO ROW. Not a greyed one -- a control appears where it can be
-- used, and a place you can travel to and find empty is a control that does nothing. You cannot spend
-- a day going somewhere purely to dig: the ore is what you carry off a ground you went to for work
-- (the caches, models/overworld.lua), which is where the old "Forage for the Bastion" rows went. It
-- also keeps the debut clean: on the first morning four grounds are open, the player has finished no
-- quest, and exactly one row is drawn with exactly one piece of work under it. The tutorial goes on
-- teaching by being the only thing there.
function QuestBoard:rebuild()
    local board = Quest.board(self.player)

    self.grounds = {}
    for _, ground in ipairs(board.grounds) do
        local def = Biome.get(ground.id)
        ground.name = def and def.name or ground.id
        -- `startable` rather than #quests: the locked entries appended to every ground are warnings
        -- that ride along (the Gate's countdown), and a ground carrying nothing but a warning is a
        -- ground with nothing to do on it.
        if (ground.startable or #ground.quests) > 0 then
            self.grounds[#self.grounds + 1] = ground
        end
    end

    -- Keep the player looking at the ground they were on if it is still offered -- rebuild() is called
    -- by the debug toggle mid-session, and having the list jump back to the first row under you is the
    -- kind of small betrayal that makes a panel feel broken.
    local wanted = self.groundId
    local start = 1
    for i, ground in ipairs(self.grounds) do
        if ground.id == wanted then start = i end
    end
    self.groundId = self.grounds[start] and self.grounds[start].id

    -- The relic plates belong to whichever ground is selected; a rebuilt board has none until the
    -- dossier draws again.
    self.relicRects, self.relicFocus = nil, nil

    -- Build the travel list. Choosing a ground generates the overworld from everything posted there
    -- (models/quest.lua's Quest.trip, states/game.lua).
    --
    -- HOW LONG THE GROUND STAYS OPEN rides in the row's value slot -- name left, countdown right, the
    -- same shape a settings row uses -- rather than being drawn as a second line by this panel. That
    -- was the first attempt and it printed straight through the centred label. This is the pressure the
    -- season table exists to create: a ground with sixteen days left is a shelf you can come back to,
    -- one with two is a decision being forced. It says what the number is OF -- "4 days left", never a
    -- bare 4 -- because a figure whose unit the player has to infer is one they read wrong once and
    -- stop trusting.
    local items = {}
    for _, ground in ipairs(self.grounds) do
        local left = ground.daysLeft
        items[#items + 1] = {
            label = ground.name,
            value = left and (left == 1 and "last day" or (left .. " days left")) or nil,
            action = function() self:setOut(ground) end,
        }
    end

    self.menu = Menu.new(items, {
        buttonWidth = 280,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = self.boxY + LIST_TOP,
        centerX = self.boxX + BOX_W * 0.26,
        font = self.headFont,
        maxVisible = MAX_VISIBLE,
    })
    self.menu.selected = start
end

-- The quests standing on the highlighted ground, minus the warnings that ride along with every one of
-- them. What the dossier lists and what the trip will put on the board are the same set, deliberately:
-- a player must not arrive to find work the panel never mentioned.
function QuestBoard:here()
    local ground = self.grounds[self.menu and self.menu.selected or 1]
    if not ground then return nil, {} end
    local work = {}
    for _, quest in ipairs(ground.quests) do
        if not quest.locked then work[#work + 1] = quest end
    end
    return ground, work
end

-- SET OUT. There is nothing to assemble first: the whole roster marches, and which of them take the
-- field is chosen per battle in the deployment phase, over the actual board (docs/deployment.md).
--
-- Every intro scene on the ground plays first, in board order, over the frozen city. A quest's `intro`
-- is authored to run before the company leaves, and that is still exactly when it runs -- there may
-- simply be more than one of them now. Chained rather than dropped, because an unreachable scene is a
-- scene that may as well not have been written; and in practice a house has one live quest at a time,
-- so a ground carrying three intros is the far end of the range rather than the norm.
function QuestBoard:setOut(ground)
    local trip = Quest.tripFor(self.player, ground.id)
    if not trip then return end

    local function begin()
        State.switch(require("states.game"), trip, nil, self.player)
    end

    local chain = begin
    for i = #trip.quests, 1, -1 do
        local intro = trip.quests[i].intro
        if intro then
            local nextStep = chain
            chain = function() require("models.conversation").play(intro, nextStep) end
        end
    end
    chain()
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
    -- A new ground brings a new set of relics, so the focus ring cannot survive the move -- index 2 on
    -- the last ground means nothing on this one.
    if self.lastSelected ~= self.menu.selected then
        self.lastSelected = self.menu.selected
        self.relicFocus = nil
        self.relicCache = nil
        local ground = self.grounds[self.menu.selected]
        self.groundId = ground and ground.id
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

    if #self.grounds == 0 then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf("Nowhere to go today.", self.boxX, self.boxY + BOX_H / 2,
            BOX_W, "center")
    else
        -- Left: where the company can go.
        self.menu:draw()
        self:drawCountdowns()
        -- Right: what is waiting there.
        self:drawDossier()
    end

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "A: Set out    D-pad: Choose / Relics    B: Close"
        or "Click a ground / Enter: Set out    Wheel: Scroll    Click X / Esc: Close"
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

-- A GROUND ABOUT TO SHUT wears a red bar down its left edge.
--
-- The countdown itself is the row's value (see rebuild), and every value in a menu is drawn in the same
-- amber -- so the urgency of the last two mornings needed a cue the label colour could not give without
-- either fighting the menu's own drawing or overprinting it. A stripe is that cue: it is form rather
-- than colour-on-text, it cannot collide with anything, and it reads down the whole list at a glance,
-- which is what "this one closes first" wants to be readable as.
--
-- Two days rather than one, because a ground you can still make two trips to is a plan and a ground you
-- can make one is a decision.
function QuestBoard:drawCountdowns()
    for i, ground in ipairs(self.grounds) do
        -- ui/menu.lua parks each row's geometry on the item itself, and leaves `x` nil on a row
        -- scrolled out of sight -- which is exactly the rows this must not draw beside.
        local item = self.menu.items[i]
        local left = ground.daysLeft
        if item and item.x and left and left <= 2 then
            Theme.set(Theme.accentWeapon)
            love.graphics.rectangle("fill", item.x, item.y + 4, 3, item.h - 8, 1.5, 1.5)
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

-- THE GROUND'S DOSSIER: everything that would be on the board if the company went there today.
--
-- It has to argue for a PLACE, which is a different job from the old card's. A quest card described one
-- piece of work; this lists all of them, warns about the deepest fight among them (the one most likely
-- to end the day badly), and shows every relic the ground could pay out.
--
-- EACH PIECE OF WORK SAYS WHAT IT IS. It used to give a title and a house -- "The Haunted Mill / The
-- Cathedral" -- which names a thing without describing it, so two grounds offering three titles each
-- were six words the player could not choose between. The blueprints have carried a `description` the
-- whole time -- all 92 of them author one -- and that sentence is what makes the row a decision;
-- printing the title alone was simply leaving it on the floor.
--
-- The count that stood at the top of this pane -- "2 pieces of work here" -- is gone with it. It was
-- reporting the length of the list directly under it, which the list already says by being that long,
-- and it cost a line the prose now has better use for.
function QuestBoard:drawDossier()
    local ground, work = self:here()
    if not ground then return end

    local x = self.boxX + BOX_W * 0.50
    local w = BOX_W * 0.44
    local y = self.boxY + LIST_TOP - 12

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.ink)
    love.graphics.printf(ground.name, x, y, w, "left")

    love.graphics.setFont(self.bodyFont)
    local lineH = self.bodyFont:getHeight()
    local cy = y + 34

    -- `maxLines` clamps a run of prose to the height the pane can spare and says so with an ellipsis;
    -- `indent` steps a block in under the title it belongs to.
    local function row(text, colour, gap, maxLines, indent)
        Theme.set(colour or Theme.muted)
        indent = indent or 0
        -- Wrap by hand and print line by line, rather than letting printf do it, because the clamp
        -- needs the line count BEFORE anything is drawn. Advancing by what the text actually occupied
        -- is the same reason it was measured before: these lines wrap -- the floor warning names two
        -- levels and runs to two lines in the pane's width -- and a fixed step drew the next row
        -- straight through it.
        local _, lines = self.bodyFont:getWrap(text, w - indent)
        if #lines == 0 then lines = { text } end
        if maxLines and #lines > maxLines then
            local kept = {}
            for i = 1, maxLines do kept[i] = lines[i] end
            -- Theme.ellipsize cannot do this one: it trims only what OVERFLOWS, and the last kept
            -- line already fits by construction, so the "..." has to be trimmed back into instead.
            local tail = kept[maxLines]
            while #tail > 1 and self.bodyFont:getWidth(tail .. "...") > w - indent do
                tail = tail:sub(1, #tail - 1)
            end
            kept[maxLines] = tail:gsub("%s+$", "") .. "..."
            lines = kept
        end
        for i, line in ipairs(lines) do love.graphics.print(line, x + indent, cy + (i - 1) * lineH) end
        cy = cy + #lines * lineH + (gap or 4)
    end

    -- THE DEEPEST FIGHT ON THE GROUND, AS A WARNING RATHER THAN AN AMBUSH. A day can now be spent on
    -- several pieces of work at once, so the number that matters is the hardest thing out there -- what
    -- the company has to survive to come home with anything. It reads RED when they are under it.
    local floor
    for _, quest in ipairs(work) do
        if quest.floorLevel and (not floor or quest.floorLevel > floor) then floor = quest.floorLevel end
    end
    local relics = self:groundRelics(work)

    -- WHAT THE PANE HAS ALREADY SPOKEN FOR, measured before a word of prose is drawn. The warning and
    -- the relic plates are fixed -- neither can be shortened without deleting something the player
    -- needs -- so the descriptions are what gives when a ground is busy.
    local reserved = 0
    if floor then reserved = reserved + 6 + 2 * lineH + GAP end
    if #relics > 0 then
        local _, iconsH = relicBlock(#relics, w)
        reserved = reserved + 2 + lineH + 2 + iconsH + 6
    end
    -- The footer hint is the floor of this column, not the box's edge.
    local room = (self.boxY + BOX_H - 46) - cy - reserved

    -- HOW DEEP A RUN OF PROSE THE COLUMN CAN AFFORD EVERY PIECE OF WORK EQUALLY. Six is a ceiling on
    -- the SEARCH rather than on the prose: the longest description in the data wraps to four lines in
    -- this column, so a ground quiet enough to be offered six is simply printing all of them whole.
    -- The same number for all of them, because a ground whose first quest is described and whose last
    -- is a bare name reads as a rendering fault rather than as a list.
    --
    -- Zero is the floor, and it spends the column on HEADS: every quest keeps its title and its house
    -- whatever else has to be cut, because a piece of work the panel never mentioned is one the player
    -- will still walk into on the ground (see `here` -- the dossier and the trip are the same list).
    -- One to four pieces of work is what a real morning offers and all of those describe themselves;
    -- only the debug toggle's eight-on-one-ground reaches the floor.
    local allowance = 0
    for a = 6, 1, -1 do
        if #work * (lineH * (1 + a) + GAP) <= room then
            allowance = a
            break
        end
    end

    -- WHEN EVEN THE TITLES DO NOT FIT. Only the debug toggle reaches this: it drops every gate, so a
    -- house's whole ten-quest line stands on its ground at once and the tundra ends up holding
    -- nineteen. A real morning posts one live quest per house. What the column does about it is keep
    -- what fits and COUNT the rest -- painting past the panel's own bottom edge tells the player
    -- nothing, and silently stopping short would have the pane understating what is out there, which
    -- is the one thing it may never do.
    local shown = #work
    local maxHeads = math.max(1, math.floor(room / (lineH + GAP)))
    if shown > maxHeads then shown = math.max(1, maxHeads - 1) end

    -- The work itself: what it is, and who posted it. This is the list that will be standing on the
    -- board as a checklist an hour from now, so it is the same list in the same order.
    for i = 1, shown do
        local quest = work[i]
        -- The title and the house share ONE baseline -- the same label-left / value-right shape the
        -- ground rows wear on the other side of this panel -- so the house costs no line of its own.
        -- A long title yields to it rather than overprinting; nothing here runs past about 30
        -- characters, so the trim is a backstop rather than a regular event.
        -- ...and the house wears its MARK here, immediately left of its own name. This is the only
        -- place the two are ever seen together, and it is the place that has to teach the mark: an hour
        -- from now that same shape will be standing alone on a tile out on the ground, saying which of
        -- the three writs on the board belongs to the shelf you are shopping for (ui/vendor_icons.lua,
        -- ui/overworld_map.lua). A house with no mark simply prints its name, as it always did.
        local house = quest.sponsorName
        local markW = VendorIcons.has(quest.sponsor) and (lineH * 0.8 + 5) or 0
        local houseW = house and (self.bodyFont:getWidth(house) + markW + 14) or 0
        Theme.set(Theme.ink)
        love.graphics.print(Theme.ellipsize(quest.name, self.bodyFont, w - houseW), x, cy)
        if house then
            Theme.set(Theme.muted)
            love.graphics.printf(house, x, cy, w, "right")
            if markW > 0 then
                local mark = lineH * 0.8
                VendorIcons.draw(quest.sponsor,
                    x + w - self.bodyFont:getWidth(house) - mark - 5, cy + (lineH - mark) / 2,
                    mark, mark, Theme.muted[1], Theme.muted[2], Theme.muted[3])
            end
        end
        cy = cy + lineH

        if allowance > 0 and quest.description then
            row(quest.description, Theme.muted, GAP, allowance, 12)
        else
            cy = cy + GAP
        end
    end
    if shown < #work then
        row(string.format("and %d more posted here", #work - shown), Theme.muted, GAP)
    end

    if floor then
        cy = cy + 6
        local ours = Growth.levelForPrestige(self.player and self.player.prestige or 1)
        if ours < floor then
            row(string.format("The hardest fight here is level %d -- your company is %d", floor, ours),
                Theme.accentWeapon, GAP)
        else
            row(string.format("The hardest fight here is level %d", floor), Theme.muted, GAP)
        end
    end

    -- THE RELICS, AND ONLY THE RELICS. `rewardCharacter` is deliberately NOT read here: the board is
    -- read before the work, and printing "Clem joins your party" hands you the ending of a scene whose
    -- whole job is to earn her. A companion arrives through the outro and the join banner
    -- (Conversation.pendingJoins), which is where the surprise belongs -- the board promises gear.
    if #relics > 0 then
        cy = cy + 2
        row(#relics == 1 and "Relic" or "Relics", Theme.muted, 2)
        cy = cy + self:drawRelicIcons(relics, x, cy, w) + 6
    else
        self.relicRects = nil
    end
end

-- Every relic promised by anything on this ground, instantiated so the hover tooltip can quote the
-- real thing (its stats, its ability, its flavour) rather than a name. Memoized per ground:
-- instantiation copies the whole blueprint, and the dossier rebuilds every frame. An id that has been
-- renamed out of the data yields `{ id = id }` with no item, so a stale reference reads as an odd
-- plate rather than crashing Item.instantiate.
function QuestBoard:groundRelics(work)
    if self.relicCache then return self.relicCache end

    local relics = {}
    for _, quest in ipairs(work) do
        for _, id in ipairs(quest.rewardItems or {}) do
            relics[#relics + 1] = { id = id, item = Item.defs[id] and Item.instantiate(id) or nil }
        end
    end
    self.relicCache = relics
    return relics
end

-- Draw the relic plates in a row at (x, cy), wrapping into a second row when a ground promises more
-- than one holds, and stopping at RELIC_ROWS. Records each plate's rect in self.relicRects so the hover
-- test and the keyboard/gamepad focus ring both read the same geometry -- and so a plate the cap left
-- undrawn cannot be focused into. Returns the height consumed.
function QuestBoard:drawRelicIcons(relics, x, cy, w)
    local perRow, blockH, plates = relicBlock(#relics, w)
    local rects = {}

    for i = 1, plates do
        local relic = relics[i]
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
    return blockH
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
-- nil-safe on a ground promising none -- left/right then falls through to the menu as before.
function QuestBoard:moveRelicFocus(dir)
    local n = self.relicRects and #self.relicRects or 0
    if n == 0 then return false end
    local i = (self.relicFocus or 0) + dir
    if i < 1 then i = n elseif i > n then i = 1 end
    self.relicFocus = i
    return true
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

-- Hand over the close X or any ground row; arrow elsewhere. See ui/cursor.lua.
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
    -- tooltip. It falls through to the menu when the ground promises no relic, where the pair is a
    -- no-op anyway (a travel row carries no `adjust`).
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
