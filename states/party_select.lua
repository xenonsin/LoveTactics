-- Party composition state: the pre-quest step where the player picks which up-to-4 roster members
-- deploy AND how they stand at the opening bell. Reached from the Quest Board (which switches here
-- instead of straight to states.game); Embark commits the chosen party and enters the overworld, Back
-- returns to the hub.
--
-- The roster is unbounded but a quest fields only Player.MAX_PARTY, so this is a scrollable grid of
-- roster cards under a MARCHING GRID of deploy cells. Toggling a card adds/removes it from player.party
-- via the existing Player.addToParty / Player.removeFromParty (party members are the same instances as
-- roster members, so nothing is copied) and drops it into the first free cell of the marching grid.
-- That grid IS the persistent formation (models/player.lua): its top row is the FRONT LINE, nearest the
-- enemy, and models/arena.lua seats the party into exactly this shape when the battle opens. Pick a
-- cell up and drop it on another to rearrange (a swap) -- so front/back and flanks are the player's
-- call, which is what makes a trait like Formation Fighter something you choose rather than a coin flip.
--
-- Three-input + mouse-only: click cards / cells / Embark / Back, or drive a cursor with arrows/D-pad,
-- Space/A to toggle a card or pick-up/drop a cell, Enter/Start to embark, Esc/B to go back (or to drop
-- a held member first).

local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")
local Player = require("models.player")

local ps = {}

local titleFont = love.graphics.newFont(30)
local headFont = love.graphics.newFont(20)
local bodyFont = love.graphics.newFont(16)
local smallFont = love.graphics.newFont(13)

-- Marching grid of deploy cells (Player.FORMATION_COLS x Player.FORMATION_ROWS). Row 1 is drawn at the
-- TOP and is the front line; deeper rows step back toward the party's own edge. Kept deliberately compact
-- -- two rows of small portraits -- so it leaves the roster grid below its old two visible rows.
local CELL, CELL_GAP = 66, 12
local GRID_LABEL_Y = 84 -- the "front line ->" caption sits here; the cells begin just below it
local DEPLOY_TOP = 104

-- Roster card grid.
local CARD_W, CARD_H, CARD_GAP = 140, 156, 16
local GRID_TOP = 300
local GRID_COLS = 6

local backButton = { x = 40, y = 656, w = 160, h = 46 }
local embarkButton = { x = Scale.WIDTH - 200, y = 656, w = 160, h = 46 }

-- Per-run state.
local quest, prestige, player, chars
local cursor, offset, gridRowsVisible, gridX
local message
-- Focus + the marching grid's own cursor. `gridFocus` puts the cursor on the deploy cells instead of
-- the roster cards; `deployCol`/`deployRow` are where it sits there; `grabbed` is the member the
-- KEYBOARD/PAD picked up for a move (nil otherwise), so the second confirm drops (and swaps) rather
-- than re-grabbing. `drag` is the MOUSE equivalent -- a member (from a cell or a roster card) being
-- dragged to a cell -- and `mx`/`my` track the pointer so the dragged portrait follows it.
local gridFocus, deployCol, deployRow, grabbed
local drag, mx, my
local DRAG_THRESHOLD = 5 -- a press that never moves this far is a click, not a drag
-- What this screen is FOR this time round. The picking is the same job whoever is asking -- a
-- roster, four slots, and the same three-input handling -- so a caller that commits somewhere other
-- than the overworld supplies its own ending rather than getting a second copy of the screen. Empty
-- for the quest flow, which keeps every default below.
local mode

local function rectContains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- `opts` (optional) re-points the screen without changing how it picks:
--   title, subtitle   -- what it says it is for
--   embarkLabel       -- the commit button's word ("Embark", "Send Build", ...)
--   onEmbark(player)  -- what committing means; defaults to entering the overworld with `quest`
--   onBack()          -- defaults to the hub
function ps.enter(_, q, pr, pl, opts)
    quest = q
    prestige = pr or 1
    player = pl or Player.active
    mode = opts or {}
    chars = (player and player.roster) or {}
    cursor = 1
    offset = 0
    message = nil
    gridFocus, deployCol, deployRow, grabbed = false, 1, 1, nil
    drag, mx, my = nil, 0, 0

    -- Everyone already deployed must sit somewhere on the grid -- an older save (or a party assembled
    -- before formations existed) arrives with members but no cells, so seat any without one before the
    -- screen is drawn. Idempotent: a member who already has a cell keeps it.
    for _, m in ipairs(player and player.party or {}) do
        if not Player.formationSlot(player, m) then
            local col, row = ps.firstFreeCell()
            if col then Player.setFormationSlot(player, m, col, row) end
        end
    end

    local gridW = GRID_COLS * CARD_W + (GRID_COLS - 1) * CARD_GAP
    gridX = (Scale.WIDTH - gridW) / 2
    local gridH = (backButton.y - 20) - GRID_TOP
    gridRowsVisible = math.max(1, math.floor((gridH + CARD_GAP) / (CARD_H + CARD_GAP)))
end

-- ---------------------------------------------------------------------------
-- Party membership + formation helpers
-- ---------------------------------------------------------------------------

local function partyIndexOf(char)
    for i, m in ipairs(player.party) do
        if m == char then return i end
    end
    return nil
end

-- The deployed member standing on marching cell (col, row), or nil. Only party members count: a
-- benched member's stale formation slot never blocks a cell here.
local function memberAt(col, row)
    for _, m in ipairs(player.party) do
        local slot = Player.formationSlot(player, m)
        if slot and slot.col == col and slot.row == row then return m end
    end
    return nil
end

-- The first empty grid cell, front row left-to-right then back -- where a freshly deployed member
-- lands. Returns col, row, or nil when the grid is somehow full (it holds MAX_PARTY with room to spare,
-- so this only happens if the caller over-fills it).
function ps.firstFreeCell()
    for row = 1, Player.FORMATION_ROWS do
        for col = 1, Player.FORMATION_COLS do
            if not memberAt(col, row) then return col, row end
        end
    end
    return nil
end

-- Add/remove `char` from the deployable party, keeping the marching grid in step: a newly deployed
-- member drops into the first free cell, a removed one gives its cell up. Naming the "full" case
-- matters -- a click that does nothing reads as a bug.
local function toggleMember(char)
    if not char then return end
    if partyIndexOf(char) then
        Player.removeFromParty(player, char)
        Player.clearFormationSlot(player, char)
        if grabbed == char then grabbed = nil end
        message = nil
    elseif not Player.addToParty(player, char) then
        message = "Party is full (" .. Player.MAX_PARTY .. "). Remove one first."
    else
        local col, row = ps.firstFreeCell()
        if col then Player.setFormationSlot(player, char, col, row) end
        message = nil
    end
end

-- Place `char` onto marching cell (col, row), deploying them first if they are not already in the
-- party (a member dragged in from the roster). The occupant of an occupied cell is swapped away rather
-- than left cell-less: a freshly deployed mover is given a free cell of its own first, so the ensuing
-- Player.setFormationSlot is a clean swap that keeps every deployed member visible on the grid. Returns
-- false (with a message) when the party is full and the member could not be deployed.
local function placeMemberAt(char, col, row)
    if not char then return false end
    if not partyIndexOf(char) then
        if not Player.addToParty(player, char) then
            message = "Party is full (" .. Player.MAX_PARTY .. "). Remove one first."
            return false
        end
        local fc, fr = ps.firstFreeCell()
        if fc then Player.setFormationSlot(player, char, fc, fr) end
    end
    Player.setFormationSlot(player, char, col, row)
    message = nil
    return true
end

-- Confirm on the marching grid: drop a held member onto the cursor cell (Player.setFormationSlot swaps
-- with whoever is already there), else pick up the member on the cell to move it. Confirming an empty
-- cell with empty hands does nothing.
local function gridConfirm()
    if grabbed then
        Player.setFormationSlot(player, grabbed, deployCol, deployRow)
        grabbed = nil
        message = nil
    else
        local m = memberAt(deployCol, deployRow)
        if m then grabbed = m end
    end
end

local function embark()
    if #player.party == 0 then
        message = "Select at least one member to deploy."
        return
    end
    -- Saved before handing over either way: the chosen party AND its formation are a real change to the
    -- player whether it is about to walk into a quest or be frozen into a build.
    Player.save()
    if mode.onEmbark then return mode.onEmbark(player) end
    State.switch(require("states.game"), quest, prestige, player)
end

local function goBack()
    if mode.onBack then return mode.onBack() end
    State.switch(require("states.hub"))
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

-- Marching cell (col, row): row 1 is the front line and is drawn at the top. Centred as a block so the
-- grid reads as one formation rather than a row of loose boxes.
local function cellRect(col, row)
    local cols = Player.FORMATION_COLS
    local total = cols * CELL + (cols - 1) * CELL_GAP
    local startX = (Scale.WIDTH - total) / 2
    return startX + (col - 1) * (CELL + CELL_GAP), DEPLOY_TOP + (row - 1) * (CELL + CELL_GAP), CELL, CELL
end

local function cellAt(x, y)
    for row = 1, Player.FORMATION_ROWS do
        for col = 1, Player.FORMATION_COLS do
            local cx, cy, cw, ch = cellRect(col, row)
            if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then return col, row end
        end
    end
    return nil
end

local function cardRect(i)
    local row = math.floor((i - 1) / GRID_COLS)
    local col = (i - 1) % GRID_COLS
    local visRow = row - offset
    if visRow < 0 or visRow >= gridRowsVisible then return nil end
    return gridX + col * (CARD_W + CARD_GAP), GRID_TOP + visRow * (CARD_H + CARD_GAP), CARD_W, CARD_H
end

local function cardIndexAt(x, y)
    for i = 1, #chars do
        local rx, ry, rw, rh = cardRect(i)
        if rx and x >= rx and x <= rx + rw and y >= ry and y <= ry + rh then return i end
    end
    return nil
end

local function maxOffset()
    local rows = math.ceil(#chars / GRID_COLS)
    return math.max(0, rows - gridRowsVisible)
end

local function scrollToCursor()
    local row = math.floor((cursor - 1) / GRID_COLS)
    if row < offset then offset = row
    elseif row >= offset + gridRowsVisible then offset = row - gridRowsVisible + 1 end
    offset = math.max(0, math.min(maxOffset(), offset))
end

-- One navigation step. On the roster grid the cursor walks the cards, and pushing UP off the top row
-- crosses into the marching grid; on the marching grid it walks the cells, and pushing DOWN off the
-- bottom row crosses back to the roster (landing under the same column). One cursor, two regions --
-- the same idiom the Loadout panel uses.
local function navigate(dc, dr)
    if gridFocus then
        local col = math.max(1, math.min(Player.FORMATION_COLS, deployCol + dc))
        local row = deployRow + dr
        if row > Player.FORMATION_ROWS then
            -- Off the bottom of the formation, into the roster under roughly the same column.
            gridFocus = false
            cursor = math.max(1, math.min(#chars, col))
            scrollToCursor()
            return
        end
        deployCol = col
        deployRow = math.max(1, row)
        return
    end
    if #chars == 0 then return end
    local row = math.floor((cursor - 1) / GRID_COLS)
    if dr < 0 and row == 0 then
        -- Off the top of the roster, up onto the marching grid's back row (nearest the roster).
        gridFocus = true
        deployCol = math.max(1, math.min(Player.FORMATION_COLS, (cursor - 1) % GRID_COLS + 1))
        deployRow = Player.FORMATION_ROWS
        return
    end
    cursor = math.max(1, math.min(#chars, cursor + dc + dr * GRID_COLS))
    scrollToCursor()
end

-- Confirm on the focused region: toggle a roster card, or pick-up/drop a marching cell.
local function confirm()
    if gridFocus then gridConfirm() else toggleMember(chars[cursor]) end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

local function drawPortrait(char, x, y, size)
    local sprite = char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(size / sw, size / sh)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3, 0.32, 0.4)
        love.graphics.rectangle("fill", x, y, size, size, 6, 6)
        love.graphics.setFont(headFont)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf((char.name or "?"):sub(1, 1), x, y + size / 2 - 12, size, "center")
    end
end

-- The marching grid: the formation the party will stand in. Front row on top, marked as the side that
-- faces the enemy so "up" reads as "toward the fight".
function ps.drawFormation()
    local cols = Player.FORMATION_COLS
    local total = cols * CELL + (cols - 1) * CELL_GAP
    local startX = (Scale.WIDTH - total) / 2

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.62, 0.66, 0.76)
    love.graphics.printf("^ front line  (faces the enemy)", startX, GRID_LABEL_Y, total, "center")

    -- Row tags to the left of the grid, so the two rows read as front/back rather than just "top/bottom".
    for row = 1, Player.FORMATION_ROWS do
        local _, cy = cellRect(1, row)
        love.graphics.setColor(0.5, 0.54, 0.64)
        love.graphics.printf(row == 1 and "FRONT" or "BACK", startX - 74, cy + CELL / 2 - 8, 66, "right")
    end

    for row = 1, Player.FORMATION_ROWS do
        for col = 1, Player.FORMATION_COLS do
            local cx, cy, cw, ch = cellRect(col, row)
            local member = memberAt(col, row)
            -- A cell reads as vacated while its member is in hand -- picked up by keyboard/pad (`grabbed`)
            -- or being dragged by the mouse.
            local held = member and (member == grabbed or (drag and drag.active and drag.char == member))
            love.graphics.setColor(0.13, 0.14, 0.19)
            love.graphics.rectangle("fill", cx, cy, cw, ch, 8, 8)
            -- A held member's cell reads as vacated (it is being moved); the front row gets a warmer
            -- frame so the leading rank is visible at a glance.
            local frame = row == 1 and { 0.72, 0.6, 0.4 } or { 0.4, 0.44, 0.56 }
            love.graphics.setColor(frame[1], frame[2], frame[3])
            love.graphics.rectangle("line", cx, cy, cw, ch, 8, 8)

            if member and not held then
                drawPortrait(member, cx + (cw - 42) / 2, cy + 4, 42)
                love.graphics.setFont(smallFont)
                love.graphics.setColor(0.9, 0.91, 0.96)
                love.graphics.printf(member.name or "?", cx + 2, cy + ch - 17, cw - 4, "center")
            elseif held then
                love.graphics.setFont(smallFont)
                love.graphics.setColor(0.55, 0.58, 0.68)
                love.graphics.printf("moving...", cx, cy + ch / 2 - 8, cw, "center")
            end

            -- Cursor ring, only while the marching grid is the focused region.
            if gridFocus and col == deployCol and row == deployRow then
                love.graphics.setColor(0.6, 0.75, 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", cx - 2, cy - 2, cw + 4, ch + 4, 9, 9)
                love.graphics.setLineWidth(1)
            end
        end
    end
end

function ps.draw()
    love.graphics.setColor(0.08, 0.09, 0.12)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf(mode.title or "Choose Your Party", 0, 28, Scale.WIDTH, "center")
    -- A quest names itself and its difficulty; any other caller says its own piece instead.
    local subtitle = mode.subtitle
    if not subtitle and quest then
        subtitle = (quest.name or "") .. "   -   Difficulty " .. tostring(quest.difficulty or "?")
    end
    if subtitle then
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.7, 0.74, 0.82)
        love.graphics.printf(subtitle, 0, 64, Scale.WIDTH, "center")
    end

    ps.drawFormation()

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.8, 0.82, 0.88)
    local _, lastY = cellRect(1, Player.FORMATION_ROWS)
    love.graphics.printf(#player.party .. " / " .. Player.MAX_PARTY .. " deployed",
        0, lastY + CELL + 4, Scale.WIDTH, "center")

    -- Roster grid.
    love.graphics.setFont(headFont)
    love.graphics.setColor(0.75, 0.78, 0.86)
    love.graphics.print("Roster", gridX, GRID_TOP - 30)

    for i = 1, #chars do
        local rx, ry = cardRect(i)
        if rx then ps.drawCard(chars[i], i, rx, ry) end
    end
    if maxOffset() > 0 then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.6, 0.64, 0.75, offset > 0 and 0.9 or 0.2)
        love.graphics.printf("^ more above", gridX, GRID_TOP - 30, Scale.WIDTH - gridX * 2, "right")
        love.graphics.setColor(0.6, 0.64, 0.75, offset < maxOffset() and 0.9 or 0.2)
        love.graphics.printf("v more below", gridX, backButton.y - 22, Scale.WIDTH - gridX * 2, "right")
    end

    -- Message line: a held member's prompt, or a membership error.
    local line = message
    if not line and grabbed then line = "Moving " .. (grabbed.name or "member") .. " -- pick a cell to place them." end
    if line then
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(message and 0.9 or 0.7, message and 0.6 or 0.78, message and 0.55 or 0.9)
        love.graphics.printf(line, 0, backButton.y - 30, Scale.WIDTH, "center")
    end

    -- Buttons.
    ps.drawButton(backButton, "Back", false)
    ps.drawButton(embarkButton, mode.embarkLabel or "Embark", #player.party > 0)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local commit = mode.embarkLabel or "Embark"
    local hint = InputMode.isGamepad()
        and ("D-pad: move  |  A: add / move  |  Start: " .. commit .. "  |  B: Back")
        or ("Click a member to add/remove  |  Drag to arrange the line  |  Enter: " .. commit
            .. "  |  Esc: Back")
    love.graphics.printf(hint, 0, Scale.HEIGHT - 24, Scale.WIDTH, "center")

    -- The dragged member's portrait, riding the cursor above everything else.
    if drag and drag.active and drag.char then
        drawPortrait(drag.char, mx - 24, my - 24, 48)
    end

    love.graphics.setColor(1, 1, 1)
end

function ps.drawCard(char, i, rx, ry)
    local slot = partyIndexOf(char)
    local selected = slot ~= nil
    love.graphics.setColor(selected and 0.18 or 0.13, selected and 0.22 or 0.14, selected and 0.28 or 0.19)
    love.graphics.rectangle("fill", rx, ry, CARD_W, CARD_H, 8, 8)

    drawPortrait(char, rx + (CARD_W - 104) / 2, ry + 10, 104)

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.9, 0.91, 0.96)
    love.graphics.printf(char.name or "?", rx + 2, ry + CARD_H - 30, CARD_W - 4, "center")

    if selected then
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx, ry, CARD_W, CARD_H, 8, 8)
        love.graphics.setLineWidth(1)
        -- Deployed badge: a check, since the marching grid now shows the ordering the slot number used to.
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.circle("fill", rx + CARD_W - 14, ry + 14, 11)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.1, 0.1, 0.14)
        love.graphics.printf("v", rx + CARD_W - 25, ry + 7, 22, "center")
    end

    -- Roster cursor, only while the roster is the focused region (so focus is never ambiguous between
    -- the two grids).
    if not gridFocus and i == cursor then
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx - 2, ry - 2, CARD_W + 4, CARD_H + 4, 9, 9)
        love.graphics.setLineWidth(1)
    end
end

function ps.drawButton(r, label, enabled)
    love.graphics.setColor(enabled and 0.2 or 0.14, enabled and 0.26 or 0.15, enabled and 0.34 or 0.19)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
    love.graphics.setColor(enabled and 0.6 or 0.35, enabled and 0.72 or 0.38, enabled and 0.9 or 0.46)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
    love.graphics.setFont(headFont)
    love.graphics.setColor(enabled and 0.95 or 0.5, enabled and 0.95 or 0.52, enabled and 0.97 or 0.58)
    love.graphics.printf(label, r.x, r.y + r.h / 2 - 12, r.w, "center")
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

-- Hand over the Back / Embark buttons, an occupied marching cell (click to pick up / drop), or a
-- character card; arrow over the rest. See ui/cursor.lua.
function ps.cursorKind(_, x, y)
    if rectContains(backButton, x, y) or rectContains(embarkButton, x, y) then return "hand" end
    local col, row = cellAt(x, y)
    if col and (grabbed or memberAt(col, row)) then return "hand" end
    return cardIndexAt(x, y) and "hand" or "arrow"
end

-- A press starts a POTENTIAL drag rather than acting at once: the actual add/toggle/move is decided on
-- release, once we know whether the pointer moved far enough to be a drag (a member carried to a cell)
-- or stayed put (a plain click). Buttons act immediately -- you do not drag Embark.
function ps.mousepressed(x, y, button)
    if button ~= 1 then return end
    mx, my = x, y
    if rectContains(backButton, x, y) then goBack() return end
    if rectContains(embarkButton, x, y) then embark() return end

    local col, row = cellAt(x, y)
    if col then
        gridFocus, deployCol, deployRow = true, col, row
        -- A keyboard/pad pickup already in hand drops here on a click -- the mouse doesn't hijack it.
        if grabbed then gridConfirm() return end
        local member = memberAt(col, row)
        if member then
            drag = { kind = "cell", char = member, x = x, y = y, startX = x, startY = y, active = false }
        end
        return
    end

    local ci = cardIndexAt(x, y)
    if ci then
        gridFocus = false
        cursor = ci
        drag = { kind = "card", char = chars[ci], x = x, y = y, startX = x, startY = y, active = false }
    elseif grabbed then
        -- A click into empty space with a member in hand puts them back down where they were.
        grabbed = nil
    end
end

function ps.mousemoved(x, y)
    mx, my = x, y
    if not drag then return end
    drag.x, drag.y = x, y
    if not drag.active
        and (math.abs(x - drag.startX) > DRAG_THRESHOLD or math.abs(y - drag.startY) > DRAG_THRESHOLD) then
        drag.active = true
    end
end

-- Release decides what the press meant. A real drag drops its member onto whatever cell it was let go
-- over (placing/deploying + swapping); a drag that ended off any cell is cancelled. A press that never
-- moved is a plain click: pick-up/drop on a cell, add/remove on a roster card.
function ps.mousereleased(x, y, button)
    if button ~= 1 or not drag then return end
    local d = drag
    drag = nil
    local col, row = cellAt(x, y)
    if d.active then
        if col then placeMemberAt(d.char, col, row) end
        -- Dropped off the grid: nothing moves (removal lives on the roster card, not a drag-to-void).
    elseif d.kind == "cell" then
        gridConfirm() -- a click on a cell: pick the member up (or drop a held one)
    else -- a click on a roster card
        toggleMember(d.char)
    end
end

function ps.wheelmoved(_, dy)
    if dy == 0 then return end
    offset = math.max(0, math.min(maxOffset(), offset - dy))
end

function ps.keypressed(key)
    if key == "escape" then
        if grabbed then grabbed = nil else goBack() end
    elseif key == "return" or key == "kpenter" then embark()
    elseif key == "space" then confirm()
    elseif key == "left" or key == "a" then navigate(-1, 0)
    elseif key == "right" or key == "d" then navigate(1, 0)
    elseif key == "up" or key == "w" then navigate(0, -1)
    elseif key == "down" or key == "s" then navigate(0, 1)
    end
end

function ps.gamepadpressed(_, button)
    if button == "b" then
        if grabbed then grabbed = nil else goBack() end
    elseif button == "start" then embark()
    elseif button == "a" then confirm()
    elseif button == "dpleft" then navigate(-1, 0)
    elseif button == "dpright" then navigate(1, 0)
    elseif button == "dpup" then navigate(0, -1)
    elseif button == "dpdown" then navigate(0, 1)
    end
end

return ps
