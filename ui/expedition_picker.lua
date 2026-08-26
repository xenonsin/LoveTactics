-- WHO GOES DOWN: four slots over the company, and you drag a body into one.
--
-- The Gate asked this with a list of toggle rows, which is the wrong shape for the question. A party is
-- a thing with POSITIONS in it and a company is a thing you look across, and a column of ticked labels
-- says neither -- it reads as a settings screen for a decision that is really "these four, and that one
-- stays home". So: a row of four plates for the expedition, the roster laid out under it, and the body
-- moves between them.
--
-- THREE INPUTS, AND THE SAME TWO GRAMMARS THE LOADOUT ALREADY USES (ui/panels/party.lua):
--   * a MOUSE drags -- pick a tile up, drop it on a plate; drag a plate's body off to send them home.
--   * a KEYBOARD or PAD picks-then-places -- confirm to lift, move, confirm to set down.
-- A plain click (press and release without travelling) is the shorthand for both: it sends a body to
-- the first free plate, or home again if they are already going.
--
-- IT OWNS NO STATE. The party lives on the run (Descent.party / Descent.setParty) and this widget reads
-- it every frame, so nothing here can disagree with what walks down the stair -- the same rule
-- ui/pool_grid.lua keeps against the stash.
--
-- A TILE IS A FACE AND NOTHING ELSE, so hovering one opens the body's card (ui/body_tooltip.lua) --
-- pools, what a wound has taken off the top, the stats with the gear folded in, and the kit by name.
-- Drawn by :drawHover, which the host calls after everything else on the screen.

local BodyTooltip = require("ui.body_tooltip") -- the hovered body's pools, stats and kit
local Descent = require("models.descent")
local InputMode = require("input_mode")
local Scale = require("scale")
local Theme = require("ui.theme")

local Picker = {}
Picker.__index = Picker

local TILE = 76
local GAP = 12
local SLOT_GAP = 16
-- How far a press may travel and still count as a click rather than a drag. Generous, because a plate
-- is a big target and a hand that shifts three pixels on the way down meant to tap it.
local CLICK_SLOP = 6

function Picker.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Picker)
    self.x, self.y = opts.x or 0, opts.y or 0
    self.cols = opts.cols or 5
    self.player = opts.player
    self.run = opts.run
    self.onChange = opts.onChange
    self.font = Theme.body(13)
    self.smallFont = Theme.body(11)
    -- The cursor walks one flat index space: 1..PARTY_MAX are the plates, then the roster after them.
    -- One space rather than two regions with a hand-off between them, so "up from the top row" and
    -- "down from a plate" need no special case.
    self.cursor = Descent.PARTY_MAX + 1
    self.drag = nil -- { from = "slot"|"roster", index = n, char = c, x, y, moved = false }
    return self
end

-- ---------------------------------------------------------------------------
-- What is where
-- ---------------------------------------------------------------------------

function Picker:party()
    return Descent.party(self.run, self.player)
end

function Picker:roster()
    return (self.player or {}).roster or {}
end

-- LEFT-ALIGNED WITH THE COMPANY BELOW, not centred over it. Centring reads as a mistake at these
-- widths: four plates over five tiles inset the top row by half a column, so the two rows share no
-- edge and the eye has nothing to hang the comparison on.
function Picker:slotRect(i)
    return self.x + (i - 1) * (TILE + SLOT_GAP), self.y, TILE, TILE
end

-- THE INN IS NOT ON THIS ROW ANY MORE. It was a fifth plate out to the right, and a body dropped on it
-- was put to bed for coin -- which made the departure row answer two questions at once and read as five
-- seats with a gap in it. A bed is bought at the Inn now (ui/panels/inn.lua), in the city, at the
-- counter that already sells the night. This screen asks the one thing it is for: who goes down.
--
-- A LODGED BODY STILL SHOWS HERE, dimmed among the company, because they are on the roster and not
-- available -- Descent.party filters them out of the expedition (models/gate.lua's Gate.isLodged), and a
-- name that vanished from the company while it mended would look like somebody had left.
function Picker:rosterTop()
    return self.y + TILE + 42
end

function Picker:rosterRect(i)
    local c = (i - 1) % self.cols
    local r = math.floor((i - 1) / self.cols)
    return self.x + c * (TILE + GAP), self:rosterTop() + r * (TILE + GAP), TILE, TILE
end

function Picker:height()
    local rows = math.max(1, math.ceil(#self:roster() / self.cols))
    return (self:rosterTop() - self.y) + rows * TILE + (rows - 1) * GAP
end

local function inRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Which slot / roster tile a point is over, or nil.
function Picker:slotAt(px, py)
    for i = 1, Descent.PARTY_MAX do
        if inRect(px, py, self:slotRect(i)) then return i end
    end
end

function Picker:rosterAt(px, py)
    for i = 1, #self:roster() do
        if inRect(px, py, self:rosterRect(i)) then return i end
    end
end

-- WHO THE CARD IS BEING DRAWN FOR, and where to hang it: the body under the POINTER while the mouse is
-- the live device, and the body under the keyboard/pad CURSOR otherwise. Two devices, one readout --
-- the same rule ui/panels/party.lua keeps for its own hovers, and the reason a pad player is not asked
-- to remember what a tile is carrying.
--
-- Anchored on the pointer for a mouse (where every tooltip in the game sits) and on the TILE's right
-- edge for a cursor, since a selection has a place on the screen and the pointer may be parked
-- anywhere -- or nowhere, on a pad.
function Picker:hoveredBody()
    if InputMode.isMouse() then
        if not self.mx then return nil end
        local slot = self:slotAt(self.mx, self.my)
        if slot then return self:party()[slot], self.mx, self.my end
        local ri = self:rosterAt(self.mx, self.my)
        if ri then return self:roster()[ri], self.mx, self.my end
        return nil
    end

    local char = self:charAtCursor()
    if not char then return nil end
    local x, y, w
    if self.cursor <= Descent.PARTY_MAX then
        x, y, w = self:slotRect(self.cursor)
    else
        x, y, w = self:rosterRect(self.cursor - Descent.PARTY_MAX)
    end
    return char, x + w, y
end

-- ---------------------------------------------------------------------------
-- Moving bodies
-- ---------------------------------------------------------------------------

local function idsOf(list)
    local out = {}
    for i, c in ipairs(list) do out[i] = c.id end
    return out
end

function Picker:commit(ids)
    Descent.setParty(self.run, ids)
    if self.onChange then self.onChange() end
end

function Picker:isGoing(charId)
    for _, c in ipairs(self:party()) do
        if c.id == charId then return true end
    end
    return false
end

-- Send a body home. A no-op for one who is not going, so a stray drop cannot shorten the party.
function Picker:remove(charId)
    local ids = {}
    for _, c in ipairs(self:party()) do
        if c.id ~= charId then ids[#ids + 1] = c.id end
    end
    self:commit(ids)
end

-- Put `charId` on plate `slot`. WHOEVER WAS THERE GOES HOME rather than shuffling along, because a
-- swap is what the gesture looks like: you dropped somebody onto an occupied plate, and the plate holds
-- one. Dropping onto a plate past the end of a short party appends instead.
function Picker:place(charId, slot)
    local ids = {}
    for _, c in ipairs(self:party()) do
        if c.id ~= charId then ids[#ids + 1] = c.id end
    end
    -- Re-find the target after removing the dragged body, or moving somebody left along their own party
    -- lands them one plate short of where they were dropped.
    slot = math.max(1, math.min(slot, #ids + 1))
    table.insert(ids, slot, charId)
    self:commit(ids)
end

-- The click shorthand: going home if they are going, else onto the first free plate. At four of four
-- this does nothing, which is what the Gate's count line is there to explain.
function Picker:toggle(charId)
    if self:isGoing(charId) then
        self:remove(charId)
    elseif #self:party() < Descent.PARTY_MAX then
        local ids = idsOf(self:party())
        ids[#ids + 1] = charId
        self:commit(ids)
    end
end

-- ---------------------------------------------------------------------------
-- Mouse
-- ---------------------------------------------------------------------------

function Picker:mousepressed(px, py, button)
    if button ~= 1 then return false end

    local slot = self:slotAt(px, py)
    if slot then
        local char = self:party()[slot]
        if char then
            self.drag = { from = "slot", char = char, x = px, y = py, ox = px, oy = py }
            self.cursor = slot
            return true
        end
        return false
    end

    local ri = self:rosterAt(px, py)
    if ri then
        local char = self:roster()[ri]
        self.drag = { from = "roster", char = char, x = px, y = py, ox = px, oy = py }
        self.cursor = Descent.PARTY_MAX + ri
        return true
    end
    return false
end

function Picker:mousemoved(px, py)
    -- Tracked whether or not anything is in hand: the pointer's resting place is what the hover card
    -- is drawn for, and a screen with no drag in progress still has to know where the mouse is.
    self.mx, self.my = px, py
    if not self.drag then return end
    self.drag.x, self.drag.y = px, py
    local dx, dy = px - self.drag.ox, py - self.drag.oy
    if (dx * dx + dy * dy) > (CLICK_SLOP * CLICK_SLOP) then self.drag.moved = true end
end

function Picker:mousereleased(px, py, button)
    if button ~= 1 or not self.drag then return false end
    local drag = self.drag
    self.drag = nil

    -- A PRESS THAT DID NOT TRAVEL IS A CLICK, whichever half of the screen it happened on.
    if not drag.moved then
        self:toggle(drag.char.id)
        return true
    end

    local slot = self:slotAt(px, py)
    if slot then
        self:place(drag.char.id, slot)
    elseif drag.from == "slot" then
        -- Dragged off the plates and dropped anywhere else: they stay home. Dropping a ROSTER tile on
        -- open ground does nothing, which is the difference between "put this one away" and "changed
        -- my mind halfway".
        self:remove(drag.char.id)
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Keyboard and pad -- pick, move, place
-- ---------------------------------------------------------------------------

function Picker:total()
    return Descent.PARTY_MAX + #self:roster()
end

function Picker:moveCursor(dc, dr)
    local i = self.cursor
    if i <= Descent.PARTY_MAX then
        if dr > 0 then
            -- Down off the plates lands under the plate you left, as near as the roster's width allows.
            self.cursor = Descent.PARTY_MAX + math.min(#self:roster(), i)
        else
            self.cursor = math.max(1, math.min(Descent.PARTY_MAX, i + dc))
        end
        return
    end

    local ri = i - Descent.PARTY_MAX
    local c = (ri - 1) % self.cols
    if dr < 0 and ri <= self.cols then
        self.cursor = math.max(1, math.min(Descent.PARTY_MAX, c + 1))
        return
    end
    local nr = ri + dc + dr * self.cols
    if nr >= 1 and nr <= #self:roster() then self.cursor = Descent.PARTY_MAX + nr end
end

function Picker:charAtCursor()
    if self.cursor <= Descent.PARTY_MAX then return self:party()[self.cursor] end
    return self:roster()[self.cursor - Descent.PARTY_MAX]
end

-- Confirm: lift if nothing is held, set down if something is.
function Picker:activate()
    if self.held then
        local id = self.held
        self.held = nil
        if self.cursor <= Descent.PARTY_MAX then self:place(id, self.cursor) else self:toggle(id) end
        return true
    end
    local char = self:charAtCursor()
    if not char then return false end
    -- On a PLATE, confirm sends them home -- the common thing to want there, and it saves a lift and a
    -- drop for "not this one". On a roster tile it is the toggle.
    if self.cursor <= Descent.PARTY_MAX then self:remove(char.id) else self:toggle(char.id) end
    return true
end

-- Lift, for the pick-then-place route: hold a body, move, confirm on a plate to set them there.
function Picker:lift()
    local char = self:charAtCursor()
    if char then self.held = char.id end
end

function Picker:keypressed(key)
    if key == "left" or key == "a" then self:moveCursor(-1, 0) return true end
    if key == "right" or key == "d" then self:moveCursor(1, 0) return true end
    if key == "up" or key == "w" then self:moveCursor(0, -1) return true end
    if key == "down" or key == "s" then self:moveCursor(0, 1) return true end
    if key == "return" or key == "kpenter" or key == "space" then return self:activate() end
    if key == "lshift" or key == "rshift" then self:lift() return true end
    if key == "escape" and self.held then self.held = nil return true end
    return false
end

function Picker:gamepadpressed(_, button)
    if button == "dpleft" then self:moveCursor(-1, 0) return true end
    if button == "dpright" then self:moveCursor(1, 0) return true end
    if button == "dpup" then self:moveCursor(0, -1) return true end
    if button == "dpdown" then self:moveCursor(0, 1) return true end
    if button == "a" then return self:activate() end
    if button == "x" then self:lift() return true end
    if button == "b" and self.held then self.held = nil return true end
    return false
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

local function drawBody(char, x, y, size, font, dim)
    local sprite = char and char.sprite
    if type(sprite) == "userdata" then
        if dim then love.graphics.setColor(0.45, 0.45, 0.48) else love.graphics.setColor(1, 1, 1) end
        local sw, sh = sprite:getDimensions()
        local scale = math.min(size / sw, size / sh) * 0.86
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", x + 6, y + 6, size - 12, size - 12, 4, 4)
        love.graphics.setFont(font)
        Theme.set(dim and Theme.frame or Theme.ink)
        love.graphics.printf(((char and char.name) or "?"):sub(1, 1), x, y + size / 2 - 9, size, "center")
    end
end

function Picker:draw()
    local Wound = require("models.wound")
    local party = self:party()

    -- THE PLATES. An empty one is drawn as a plate rather than as nothing, because four slots with two
    -- filled is the readout -- "two more may go" is the whole question this screen asks.
    for i = 1, Descent.PARTY_MAX do
        local x, y, w, h = self:slotRect(i)
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", x, y, w, h, Theme.R or 4, Theme.R or 4)
        -- A FILLED PLATE WEARS THE SPOTLIGHT GOLD, which is the one thing telling these four apart from
        -- the company underneath -- the tiles are otherwise identical, and position alone was not
        -- carrying it. An empty plate stays a hairline: it is a space, not a thing.
        local char = party[i]
        Theme.set(char and Theme.accentAmber or Theme.hairline)
        love.graphics.rectangle("line", x, y, w, h, Theme.R or 4, Theme.R or 4)
        if char then drawBody(char, x, y, w, self.font, false) end
        if self.cursor == i then
            Theme.set(Theme.cursor)
            love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4, Theme.R or 4, Theme.R or 4)
        end
    end

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local sx = self:slotRect(1)
    love.graphics.printf("The expedition", sx, self.y + TILE + 8, self.cols * (TILE + GAP), "left")

    -- THE COMPANY. Anybody already on a plate is drawn dimmed and still in place rather than removed
    -- from the list: a roster that reflowed as you picked would move the tile you were reaching for.
    for i, char in ipairs(self:roster()) do
        local x, y, w, h = self:rosterRect(i)
        local going = self:isGoing(char.id)
        local abed = require("models.gate").isLodged(self.player, char.id)
        Theme.set(Theme.panel)
        love.graphics.rectangle("fill", x, y, w, h, Theme.R or 4, Theme.R or 4)
        Theme.set((going or abed) and Theme.hairline or Theme.frame)
        love.graphics.rectangle("line", x, y, w, h, Theme.R or 4, Theme.R or 4)
        drawBody(char, x, y, w, self.font, going or abed)

        -- WHY THIS ONE IS GREYED. A body in a bed is dimmed like a body already on a plate, and with the
        -- Inn's plate gone off this row there is nothing else on the screen saying which of the two it
        -- is -- so the tile says it. One word, in the corner the wound count does not use.
        if abed then
            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.accentWeapon)
            love.graphics.printf("abed", x + 5, y + h - 15, w, "left")
        end

        -- A wound is the one fact that changes who you send, so it is on the tile rather than a hover.
        local wounds = Wound.count(self.player, char.id)
        if wounds > 0 then
            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.accentWeapon)
            love.graphics.printf("x" .. wounds, x, y + h - 15, w - 5, "right")
        end
        if self.cursor == Descent.PARTY_MAX + i then
            Theme.set(Theme.cursor)
            love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4, Theme.R or 4, Theme.R or 4)
        end
    end

    -- The body in hand, under the pointer. Drawn last so it rides over everything it is being carried
    -- across.
    if self.drag and self.drag.moved then
        drawBody(self.drag.char, self.drag.x - TILE / 2, self.drag.y - TILE / 2, TILE, self.font, false)
    end
end

-- WHAT THIS BODY IS WORTH, under the cursor (ui/body_tooltip.lua). The tiles say who; a company picked
-- four at a time is a decision about pools, wounds and kit, and without this the player answers it from
-- memory or from a trip to the Armory and back.
--
-- A SEPARATE CALL rather than the tail of :draw, because a full card -- three pools, six stats and nine
-- items -- is most of the screen tall, and everything the host draws after the company would be drawn
-- over the top of it. The host calls this last (states/gate.lua), under its own modals.
--
-- NOT WHILE SOMETHING IS IN HAND: a card that followed a dragged body would ride over the plates being
-- aimed at, and the question during a drag is where they land, not what they carry.
function Picker:drawHover()
    if self.drag and self.drag.moved then return end
    local char, ax, ay = self:hoveredBody()
    if char then BodyTooltip.draw(self.player, char, ax, ay, Scale.WIDTH) end
end

return Picker
