-- Party composition state: the pre-quest step where the player picks which up-to-4 roster members
-- deploy. Reached from the Quest Board (which switches here instead of straight to states.game);
-- Embark commits the chosen party and enters the overworld, Back returns to the hub.
--
-- The roster is unbounded but a quest fields only Player.MAX_PARTY, so this is a scrollable grid of
-- roster cards with a row of deploy slots. Toggling a card adds/removes it from player.party via the
-- existing Player.addToParty / Player.removeFromParty (party members are the same instances as roster
-- members, so nothing is copied). The current party is pre-seeded as the selection.
--
-- Three-input + mouse-only: click cards / slots / Embark / Back, or drive a cursor with arrows/D-pad,
-- Space/A to toggle, Enter/Start to embark, Esc/B to go back.

local State = require("states")
local Scale = require("scale")
local Player = require("models.player")

local ps = {}

local titleFont = love.graphics.newFont(30)
local headFont = love.graphics.newFont(20)
local bodyFont = love.graphics.newFont(16)
local smallFont = love.graphics.newFont(13)

-- Deploy-slot row (Player.MAX_PARTY boxes).
local SLOT_W, SLOT_H, SLOT_GAP = 130, 130, 20
local SLOT_Y = 96

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

local function rectContains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function ps.enter(_, q, pr, pl)
    quest = q
    prestige = pr or 1
    player = pl or Player.active
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
-- Party membership helpers
-- ---------------------------------------------------------------------------

local function partyIndexOf(char)
    for i, m in ipairs(player.party) do
        if m == char then return i end
    end
    return nil
end

-- Add/remove `char` from the deployable party. Naming the "full" case matters -- a click that does
-- nothing reads as a bug.
local function toggleMember(char)
    if not char then return end
    if partyIndexOf(char) then
        Player.removeFromParty(player, char)
        message = nil
    elseif not Player.addToParty(player, char) then
        message = "Party is full (" .. Player.MAX_PARTY .. "). Remove one first."
    else
        message = nil
    end
end

local function embark()
    if #player.party == 0 then
        message = "Select at least one member to deploy."
        return
    end
    Player.save()
    State.switch(require("states.game"), quest, prestige, player)
end

local function goBack()
    State.switch(require("states.hub"))
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local function slotRect(i)
    local total = Player.MAX_PARTY * SLOT_W + (Player.MAX_PARTY - 1) * SLOT_GAP
    local startX = (Scale.WIDTH - total) / 2
    return startX + (i - 1) * (SLOT_W + SLOT_GAP), SLOT_Y, SLOT_W, SLOT_H
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

local function moveCursor(dc, dr)
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
    love.graphics.setColor(0.08, 0.09, 0.12)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Choose Your Party", 0, 28, Scale.WIDTH, "center")
    if quest then
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.7, 0.74, 0.82)
        love.graphics.printf((quest.name or "") .. "   -   Difficulty " .. tostring(quest.difficulty or "?"),
            0, 64, Scale.WIDTH, "center")
    end

    -- Deploy slots.
    for i = 1, Player.MAX_PARTY do
        local sx, sy, sw, sh = slotRect(i)
        local member = player.party[i]
        love.graphics.setColor(0.13, 0.14, 0.19)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 8, 8)
        love.graphics.setColor(0.4, 0.44, 0.56)
        love.graphics.rectangle("line", sx, sy, sw, sh, 8, 8)
        if member then
            drawPortrait(member, sx + (sw - 96) / 2, sy + 8, 96)
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.9, 0.91, 0.96)
            love.graphics.printf(member.name or "?", sx + 2, sy + sh - 22, sw - 4, "center")
        else
            love.graphics.setFont(bodyFont)
            love.graphics.setColor(0.4, 0.42, 0.5)
            love.graphics.printf("Empty", sx, sy + sh / 2 - 10, sw, "center")
        end
    end
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(#player.party .. " / " .. Player.MAX_PARTY .. " deployed",
        0, SLOT_Y + SLOT_H + 8, Scale.WIDTH, "center")

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

    -- Message line.
    if message then
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.9, 0.6, 0.55)
        love.graphics.printf(message, 0, backButton.y - 30, Scale.WIDTH, "center")
    end

    -- Buttons.
    ps.drawButton(backButton, "Back", false)
    ps.drawButton(embarkButton, "Embark", #player.party > 0)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    love.graphics.printf("Click a member to add/remove  |  Arrows + Space: toggle  |  Enter: Embark  |  Esc: Back",
        0, Scale.HEIGHT - 24, Scale.WIDTH, "center")

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
        -- Slot-number badge.
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.circle("fill", rx + CARD_W - 14, ry + 14, 11)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.1, 0.1, 0.14)
        love.graphics.printf(tostring(slot), rx + CARD_W - 25, ry + 7, 22, "center")
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

-- Hand over the Back / Embark buttons, a filled deploy slot (click removes the member), or a
-- character card; arrow over the rest. See ui/cursor.lua.
function ps.cursorKind(_, x, y)
    if rectContains(backButton, x, y) or rectContains(embarkButton, x, y) then return "hand" end
    for i = 1, Player.MAX_PARTY do
        local sx, sy, sw, sh = slotRect(i)
        if player.party[i] and x >= sx and x <= sx + sw and y >= sy and y <= sy + sh then return "hand" end
    end
    return cardIndexAt(x, y) and "hand" or "arrow"
end

function ps.mousepressed(x, y, button)
    if button ~= 1 then return end
    if rectContains(backButton, x, y) then goBack() return end
    if rectContains(embarkButton, x, y) then embark() return end

    -- A filled deploy slot removes that member.
    for i = 1, Player.MAX_PARTY do
        local sx, sy, sw, sh = slotRect(i)
        if x >= sx and x <= sx + sw and y >= sy and y <= sy + sh and player.party[i] then
            toggleMember(player.party[i])
            return
        end
    end

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
    elseif key == "left" or key == "a" then moveCursor(-1, 0)
    elseif key == "right" or key == "d" then moveCursor(1, 0)
    elseif key == "up" or key == "w" then moveCursor(0, -1)
    elseif key == "down" or key == "s" then moveCursor(0, 1)
    end
end

function ps.gamepadpressed(_, button)
    if button == "b" then goBack()
    elseif button == "start" then embark()
    elseif button == "a" then toggleMember(chars[cursor])
    elseif button == "dpleft" then moveCursor(-1, 0)
    elseif button == "dpright" then moveCursor(1, 0)
    elseif button == "dpup" then moveCursor(0, -1)
    elseif button == "dpdown" then moveCursor(0, 1)
    end
end

return ps
