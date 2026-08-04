-- Company composition state: the pre-quest step where the player picks which up-to-8 roster members
-- MARCH. Reached from the Quest Board (which switches here instead of straight to states.game); Embark
-- commits the chosen company and enters the overworld, Back returns to the hub.
--
-- This screen makes no placement decision at all. It used to host a marching grid, and that grid is gone:
-- WHO fights and WHERE they stand is now chosen per battle in the deployment phase (states/battle.lua),
-- over the actual board, with the enemy already standing on it. See docs/deployment.md. So what is left
-- here is the one question the hub can honestly answer -- who comes along -- as a scrollable grid of
-- roster cards. Toggling a card adds/removes it via the existing Player.addToParty /
-- Player.removeFromParty (company members are the same instances as roster members, so nothing is copied).
--
-- Three-input + mouse-only: click cards / Embark / Back, or drive a cursor with arrows/D-pad, Space/A to
-- toggle a card, Enter/Start to embark, Esc/B to go back.

local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")
local Player = require("models.player")

local ps = {}

local Theme = require("ui.theme")
local titleFont = Theme.display(30)
local headFont = Theme.display(20)
local bodyFont = Theme.body(16)
local smallFont = Theme.body(13)

-- Roster card grid. Taller than it was: with the marching grid gone the screen has the room, and a
-- bigger portrait is what the card is for.
local CARD_W, CARD_H, CARD_GAP = 140, 168, 16
local GRID_TOP = 150
local GRID_COLS = 6

local backButton = { x = 40, y = 656, w = 160, h = 46 }
local embarkButton = { x = Scale.WIDTH - 200, y = 656, w = 160, h = 46 }

-- Per-run state.
local quest, prestige, player, chars
local cursor, offset, gridRowsVisible, gridX
local message
-- What this screen is FOR this time round. The picking is the same job whoever is asking -- a roster,
-- a capped company, and the same three-input handling -- so a caller that commits somewhere other than
-- the overworld supplies its own ending rather than getting a second copy of the screen. Empty for the
-- quest flow, which keeps every default below.
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

    local gridW = GRID_COLS * CARD_W + (GRID_COLS - 1) * CARD_GAP
    gridX = (Scale.WIDTH - gridW) / 2
    local gridH = (backButton.y - 20) - GRID_TOP
    gridRowsVisible = math.max(1, math.floor((gridH + CARD_GAP) / (CARD_H + CARD_GAP)))
end

-- ---------------------------------------------------------------------------
-- Company membership
-- ---------------------------------------------------------------------------

local function partyIndexOf(char)
    for i, m in ipairs(player.party) do
        if m == char then return i end
    end
    return nil
end

-- Add/remove `char` from the marching company. Naming the "full" case matters -- a click that does
-- nothing reads as a bug.
local function toggleMember(char)
    if not char then return end
    if partyIndexOf(char) then
        Player.removeFromParty(player, char)
        message = nil
    elseif not Player.addToParty(player, char) then
        message = "The company is full (" .. Player.MAX_PARTY .. "). Remove one first."
    else
        message = nil
    end
end

local function embark()
    if #player.party == 0 then
        message = "Pick at least one member to march."
        return
    end
    -- Saved before handing over either way: the chosen company is a real change to the player whether it
    -- is about to walk into a quest or be frozen into a build.
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

local function navigate(dc, dr)
    if #chars == 0 then return end
    cursor = math.max(1, math.min(#chars, cursor + dc + dr * GRID_COLS))
    scrollToCursor()
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

function ps.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(mode.title or "Choose Your Company", 0, 28, Scale.WIDTH, "center")
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

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(#player.party .. " / " .. Player.MAX_PARTY .. " marching", 0, 96, Scale.WIDTH, "center")
    -- Say where placement now happens, so an empty screen doesn't read as a missing formation editor.
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.58, 0.62, 0.72)
    love.graphics.printf("You will choose which " .. Player.MAX_FIELD
        .. " take the field, and where they stand, at the start of each battle.",
        0, 120, Scale.WIDTH, "center")

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

    if message then
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.9, 0.6, 0.55)
        love.graphics.printf(message, 0, backButton.y - 30, Scale.WIDTH, "center")
    end

    -- Buttons.
    ps.drawButton(backButton, "Back", false)
    ps.drawButton(embarkButton, mode.embarkLabel or "Embark", #player.party > 0)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local commit = mode.embarkLabel or "Embark"
    local hint = InputMode.isGamepad()
        and ("D-pad: move  |  A: add / remove  |  Start: " .. commit .. "  |  B: Back")
        or ("Click a member to add/remove  |  Enter: " .. commit .. "  |  Esc: Back")
    love.graphics.printf(hint, 0, Scale.HEIGHT - 24, Scale.WIDTH, "center")

    love.graphics.setColor(1, 1, 1)
end

function ps.drawCard(char, i, rx, ry)
    local selected = partyIndexOf(char) ~= nil
    love.graphics.setColor(selected and 0.18 or 0.13, selected and 0.22 or 0.14, selected and 0.28 or 0.19)
    love.graphics.rectangle("fill", rx, ry, CARD_W, CARD_H, 8, 8)

    drawPortrait(char, rx + (CARD_W - 116) / 2, ry + 10, 116)

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.9, 0.91, 0.96)
    love.graphics.printf(char.name or "?", rx + 2, ry + CARD_H - 30, CARD_W - 4, "center")

    if selected then
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx, ry, CARD_W, CARD_H, 8, 8)
        love.graphics.setLineWidth(1)
        -- Marching badge: a check, since there is no longer an ordering for a slot number to show.
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.circle("fill", rx + CARD_W - 14, ry + 14, 11)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.1, 0.1, 0.14)
        love.graphics.printf("v", rx + CARD_W - 25, ry + 7, 22, "center")
    end

    if i == cursor then
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

-- Hand over the Back / Embark buttons and the character cards; arrow over the rest. See ui/cursor.lua.
function ps.cursorKind(_, x, y)
    if rectContains(backButton, x, y) or rectContains(embarkButton, x, y) then return "hand" end
    return cardIndexAt(x, y) and "hand" or "arrow"
end

function ps.mousepressed(x, y, button)
    if button ~= 1 then return end
    if rectContains(backButton, x, y) then goBack() return end
    if rectContains(embarkButton, x, y) then embark() return end
    local ci = cardIndexAt(x, y)
    if ci then
        cursor = ci
        toggleMember(chars[ci])
    end
end

function ps.wheelmoved(_, dy)
    if dy == 0 then return end
    offset = math.max(0, math.min(maxOffset(), offset - dy))
end

function ps.keypressed(key)
    if key == "escape" then goBack()
    elseif key == "return" or key == "kpenter" then embark()
    elseif key == "space" then toggleMember(chars[cursor])
    elseif key == "left" or key == "a" then navigate(-1, 0)
    elseif key == "right" or key == "d" then navigate(1, 0)
    elseif key == "up" or key == "w" then navigate(0, -1)
    elseif key == "down" or key == "s" then navigate(0, 1)
    end
end

function ps.gamepadpressed(_, button)
    if button == "b" then goBack()
    elseif button == "start" then embark()
    elseif button == "a" then toggleMember(chars[cursor])
    elseif button == "dpleft" then navigate(-1, 0)
    elseif button == "dpright" then navigate(1, 0)
    elseif button == "dpup" then navigate(0, -1)
    elseif button == "dpdown" then navigate(0, 1)
    end
end

return ps
