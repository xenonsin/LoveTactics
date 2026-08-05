-- Build composition state: pick the team that stands in for you at the Dueling Grounds when you are
-- not here. Reached from ui/panels/pvp.lua; Publish freezes the picked team as a build
-- (models/build.lua) and returns to the hub, Back returns without publishing.
--
-- This is the LAST screen in the game that picks a subset of the roster, and it is the only place one
-- is still a real question. A quest takes the whole roster -- the company IS the roster, and which of
-- them stand on a given board is chosen per battle in the deployment phase (docs/deployment.md), so
-- the hub has nothing left to ask before an embark. A duel has no deployment phase and no bench: a
-- build is exactly the Build.TEAM_SIZE who take the field, in the order you name them, so somebody has
-- to name them. (This file is what became of the old states/party_select.lua, which asked the embark
-- question that no longer exists.)
--
-- The pick is a LOCAL list, not player state. Nothing here adds a character to anything the campaign
-- reads; publishing snapshots copies (Build.from), so the live roster is untouched either way.
--
-- Three-input + mouse-only: click cards / Publish / Back, or drive a cursor with arrows/D-pad,
-- Space/A to toggle a card, Enter/Start to publish, Esc/B to go back.

local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")
local Player = require("models.player")
local Build = require("models.build")

local bs = {}

local Theme = require("ui.theme")
local titleFont = Theme.display(30)
local headFont = Theme.display(20)
local bodyFont = Theme.body(16)
local smallFont = Theme.body(13)

local CARD_W, CARD_H, CARD_GAP = 140, 168, 16
local GRID_TOP = 150
local GRID_COLS = 6

local backButton = { x = 40, y = 656, w = 160, h = 46 }
local publishButton = { x = Scale.WIDTH - 200, y = 656, w = 160, h = 46 }

-- Per-visit state.
local player, chars, picked
local cursor, offset, gridRowsVisible, gridX
local message
-- What committing means, and what backing out means. Supplied by the caller (the Dueling Grounds
-- panel) so this screen holds no opinion about what a published build is for.
local onPublish, onBack

local function rectContains(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- `opts`:
--   onPublish(team)  what Publish means; `team` is the picked characters in pick order
--   onBack()         defaults to the hub
function bs.enter(_, pl, opts)
    opts = opts or {}
    player = pl or Player.active
    chars = (player and player.roster) or {}
    picked = {}
    onPublish = opts.onPublish
    onBack = opts.onBack
    cursor = 1
    offset = 0
    message = nil

    local gridW = GRID_COLS * CARD_W + (GRID_COLS - 1) * CARD_GAP
    gridX = (Scale.WIDTH - gridW) / 2
    local gridH = (backButton.y - 20) - GRID_TOP
    gridRowsVisible = math.max(1, math.floor((gridH + CARD_GAP) / (CARD_H + CARD_GAP)))
end

-- ---------------------------------------------------------------------------
-- The pick
-- ---------------------------------------------------------------------------

local function pickIndexOf(char)
    for i, m in ipairs(picked) do
        if m == char then return i end
    end
    return nil
end

-- Add/remove `char`. Naming the "full" case matters -- a click that does nothing reads as a bug.
local function toggle(char)
    if not char then return end
    local at = pickIndexOf(char)
    if at then
        table.remove(picked, at)
        message = nil
    elseif #picked >= Build.TEAM_SIZE then
        message = "A build is " .. Build.TEAM_SIZE .. ". Take one off first."
    else
        picked[#picked + 1] = char
        message = nil
    end
end

local function publish()
    if #picked == 0 then
        message = "Pick who stands in for you."
        return
    end
    if onPublish then onPublish(picked) end
end

local function goBack()
    if onBack then return onBack() end
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

function bs.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Assemble Your Build", 0, 28, Scale.WIDTH, "center")
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.7, 0.74, 0.82)
    love.graphics.printf("The team others face when you are not here -- and the tactics you gave it",
        0, 64, Scale.WIDTH, "center")

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.8, 0.82, 0.88)
    love.graphics.printf(#picked .. " / " .. Build.TEAM_SIZE .. " on the sand", 0, 96, Scale.WIDTH, "center")
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.58, 0.62, 0.72)
    love.graphics.printf("A duel has no bench: these are the ones who fight, at level "
        .. Build.NORMAL_LEVEL .. ", run by the tactics you wrote them.", 0, 120, Scale.WIDTH, "center")

    love.graphics.setFont(headFont)
    love.graphics.setColor(0.75, 0.78, 0.86)
    love.graphics.print("Roster", gridX, GRID_TOP - 30)

    for i = 1, #chars do
        local rx, ry = cardRect(i)
        if rx then bs.drawCard(chars[i], i, rx, ry) end
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

    bs.drawButton(backButton, "Back", false)
    bs.drawButton(publishButton, "Publish", #picked > 0)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.5, 0.55, 0.65)
    -- Show the glyphs for the device last used: pad buttons only in gamepad mode, keyboard/mouse otherwise.
    local hint = InputMode.isGamepad()
        and "D-pad: move  |  A: add / remove  |  Start: Publish  |  B: Back"
        or "Click a member to add/remove  |  Enter: Publish  |  Esc: Back"
    love.graphics.printf(hint, 0, Scale.HEIGHT - 24, Scale.WIDTH, "center")

    love.graphics.setColor(1, 1, 1)
end

function bs.drawCard(char, i, rx, ry)
    local slot = pickIndexOf(char)
    love.graphics.setColor(slot and 0.18 or 0.13, slot and 0.22 or 0.14, slot and 0.28 or 0.19)
    love.graphics.rectangle("fill", rx, ry, CARD_W, CARD_H, 8, 8)

    drawPortrait(char, rx + (CARD_W - 116) / 2, ry + 10, 116)

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.9, 0.91, 0.96)
    love.graphics.printf(char.name or "?", rx + 2, ry + CARD_H - 30, CARD_W - 4, "center")

    if slot then
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx, ry, CARD_W, CARD_H, 8, 8)
        love.graphics.setLineWidth(1)
        -- The badge is a NUMBER here, not a check: a build is stored in pick order (Build.from), so
        -- where a member sits in the four is a thing the player chose and should be able to see.
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.circle("fill", rx + CARD_W - 14, ry + 14, 11)
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.1, 0.1, 0.14)
        love.graphics.printf(tostring(slot), rx + CARD_W - 25, ry + 7, 22, "center")
    end

    if i == cursor then
        Theme.set(Theme.cursor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx - 2, ry - 2, CARD_W + 4, CARD_H + 4, 9, 9)
        love.graphics.setLineWidth(1)
    end
end

function bs.drawButton(r, label, enabled)
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

-- Hand over the Back / Publish buttons and the character cards; arrow over the rest. See ui/cursor.lua.
function bs.cursorKind(_, x, y)
    if rectContains(backButton, x, y) or rectContains(publishButton, x, y) then return "hand" end
    return cardIndexAt(x, y) and "hand" or "arrow"
end

function bs.mousepressed(x, y, button)
    if button ~= 1 then return end
    if rectContains(backButton, x, y) then goBack() return end
    if rectContains(publishButton, x, y) then publish() return end
    local ci = cardIndexAt(x, y)
    if ci then
        cursor = ci
        toggle(chars[ci])
    end
end

function bs.wheelmoved(_, dy)
    if dy == 0 then return end
    offset = math.max(0, math.min(maxOffset(), offset - dy))
end

function bs.keypressed(key)
    if key == "escape" then goBack()
    elseif key == "return" or key == "kpenter" then publish()
    elseif key == "space" then toggle(chars[cursor])
    elseif key == "left" or key == "a" then navigate(-1, 0)
    elseif key == "right" or key == "d" then navigate(1, 0)
    elseif key == "up" or key == "w" then navigate(0, -1)
    elseif key == "down" or key == "s" then navigate(0, 1)
    end
end

function bs.gamepadpressed(_, button)
    if button == "b" then goBack()
    elseif button == "start" then publish()
    elseif button == "a" then toggle(chars[cursor])
    elseif button == "dpleft" then navigate(-1, 0)
    elseif button == "dpright" then navigate(1, 0)
    elseif button == "dpup" then navigate(0, -1)
    elseif button == "dpdown" then navigate(0, 1)
    end
end

return bs
