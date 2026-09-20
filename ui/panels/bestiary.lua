-- THE BOOK: what the company has met, and what each thing it met is still holding back.
--
-- The chase board, opened from the mouth of the stair (states/gate.lua) because that is where the
-- question it answers gets asked -- what am I going down for. Not a door in the city: this is a record
-- the company keeps, not a counter somebody stands behind.
--
-- A REDACTED ROW IS THE WHOLE POINT. A body you have met lists every piece on its drop list; the ones
-- you have carried out are named, and the ones you have not are struck bars with only their DEPTH
-- showing. That is the same notation the rack already uses for a ware you have not found -- named,
-- silhouetted, with the depth it falls at where its price would go (Vendor.stock's `lockReason`) -- and
-- it is here for the same reason: a hole you can see is a destination, and a count is a number you read
-- once and forget.
--
-- THE PANEL NEVER PRINTS AN UNFOUND NAME. models/bestiary.lua hands one over so a found row can be
-- drawn and so a later surface can use it, and drawing it here would be the husk leak in another
-- material -- the striking IS the information.
--
-- Two columns, the Forge's shape: the bodies down the left, the selected one's list on the right.
--
-- EVERY ROW WEARS THE BODY'S OWN BOARD TOKEN, because a name in a list is not what the player met --
-- the thing they met was a figure standing on a tile, and that figure is what they will recognise a
-- page of them by. `sprite` is the piece off the board, never the VN portrait: only companions carry
-- one of those and no companion is ever an entry here.
--
-- Three-input + mouse-only, per project standard.

local Bestiary = require("models.bestiary")
local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Scale = require("scale")
local Sound = require("models.sound")
local Sprite = require("models.sprite")
local Theme = require("ui.theme")

local Book = {}
Book.__index = Book

local BOX_W, BOX_H = 960, 580
local PAD = 24
local LIST_W = 320
local ROW_H = 42
local ROW_GAP = 4
local TOKEN = 32       -- the body's figure on a list row
local PORTRAIT = 72    -- the same figure, at reading size, on the open entry
local MAX_ROWS = 9
local CONTENT_TOP = 104

-- The four bestiary bands (docs/bestiary.md), named rather than numbered: a tier is a label the
-- catalogue already carries and "Elite" says more than "3" to somebody reading a list of bodies.
local TIER_LABEL = { [1] = "Chaff", [2] = "Line", [3] = "Elite", [4] = "Boss" }

local function inRect(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Book.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Book)
    self.player = opts.player
    self.onClose = opts.onClose

    self.titleFont = Theme.display(28)
    self.nameFont = Theme.display(21)
    self.rowFont = Theme.display(15)
    self.bodyFont = Theme.body(13)
    self.smallFont = Theme.body(11)
    self.capFont = Theme.body(10)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.listX = self.boxX + PAD
    self.detailX = self.listX + LIST_W + PAD
    self.detailW = self.boxX + BOX_W - PAD - self.detailX

    self.entries = Bestiary.entries(self.player)
    self.sel, self.scroll = 1, 0
    self.mx, self.my = -1, -1
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function Book:close()
    if self.onClose then self.onClose() end
end

function Book:hasRows() return #self.entries > 0 end
function Book:current() return self.entries[self.sel] end

function Book:visibleCount()
    return math.min(MAX_ROWS, #self.entries)
end

function Book:clampScroll()
    local maxScroll = math.max(0, #self.entries - MAX_ROWS)
    self.scroll = math.max(0, math.min(self.scroll, maxScroll))
end

function Book:scrollToSelection()
    if self.sel <= self.scroll then self.scroll = self.sel - 1
    elseif self.sel > self.scroll + MAX_ROWS then self.scroll = self.sel - MAX_ROWS end
    self:clampScroll()
end

function Book:moveSelection(delta)
    if not self:hasRows() then return end
    self.sel = math.max(1, math.min(#self.entries, self.sel + delta))
    self:scrollToSelection()
    Sound.play("ui.move")
end

function Book:rowRect(i)
    local idx = i - self.scroll
    if idx < 1 or idx > MAX_ROWS then return nil end
    return { x = self.listX, y = self.boxY + CONTENT_TOP + (idx - 1) * (ROW_H + ROW_GAP),
        w = LIST_W, h = ROW_H }
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

-- The body's figure, on a raised plate so a token with a transparent ground still reads as framed
-- against whatever row it sits on. Art that has not landed resolves to its path string
-- (models/sprite.lua) and falls back to the initial on the same plate -- the party rail's convention
-- (ui/panels/party.lua), so a body looks like a body everywhere the game draws one.
function Book:drawToken(entry, x, y, size)
    Theme.plate(x, y, size, size, 4, Theme.panel)
    local sprite = Sprite.load(entry.sprite)
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local inner = size - 6
        local scale = math.min(inner / sw, inner / sh)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        local font = size >= PORTRAIT and self.nameFont or self.rowFont
        love.graphics.setFont(font)
        Theme.set(Theme.muted, 0.8)
        love.graphics.printf((entry.name or "?"):sub(1, 1):upper(),
            x, y + size / 2 - font:getHeight() / 2, size, "center")
    end
end

function Book:draw()
    local bx, by = self.boxX, self.boxY
    -- The same scrim every pop-up in the game lays down (ui/panels/bag.lua and its neighbours): a flat
    -- 60% black rather than a theme token, because there is no token for it and inventing one here
    -- would make this the one panel that dims differently.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.corners(bx + 6, by + 6, BOX_W - 12, BOX_H - 12, 10)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.ink)
    love.graphics.print("The Book", bx + PAD, by + 26)

    -- THE STANDING, and it is two numbers rather than one: bodies met says how much of the rift the
    -- company has seen, pieces carried says how much of what it saw it actually got. A single
    -- percentage would average those into something that answers neither.
    local met, found, total = Bestiary.standing(self.player)
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    local standing = met == 0 and "nothing met yet"
        or (met .. " met  ·  " .. found .. " of " .. total .. " carried out")
    love.graphics.print(standing, bx + PAD, by + 62)

    if not self:hasRows() then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf(
            "Nothing here yet. The book fills in as the company fights: every body it meets gets an "
            .. "entry, and every entry lists what that body is known to carry.",
            bx + PAD, by + CONTENT_TOP + 40, BOX_W - PAD * 2, "center")
        self.closeButton:draw()
        return
    end

    self:drawList()
    self:drawEntry()
    self.closeButton:draw()
end

function Book:drawList()
    for i = self.scroll + 1, math.min(#self.entries, self.scroll + MAX_ROWS) do
        local entry = self.entries[i]
        local r = self:rowRect(i)
        if r then
            local selected = (i == self.sel)
            Theme.set(selected and Theme.panel2 or Theme.slot)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 2, 2)
            if selected then
                Theme.set(Theme.cursor)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 2, 2)
                love.graphics.setLineWidth(1)
            end

            self:drawToken(entry, r.x + 6, r.y + (ROW_H - TOKEN) / 2, TOKEN)
            local textX = r.x + 6 + TOKEN + 10

            love.graphics.setFont(self.rowFont)
            Theme.set(Theme.ink)
            local name = Theme.ellipsize(entry.name, self.rowFont, r.x + r.w - 74 - textX)
            love.graphics.print(name, textX, r.y + 6)

            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.muted, 0.85)
            love.graphics.print(TIER_LABEL[entry.tier] or "", textX, r.y + 25)

            -- THE BADGE IS THE HOOK. A body with everything carried out is done with; one showing 1/4
            -- is a reason to go back, and that is the only number on this row worth reading at a
            -- glance. A body with no list at all shows nothing rather than "0 of 0" -- there is
            -- nothing to come back for, which is not the same as having found nothing.
            if entry.total > 0 then
                local label = entry.found .. "/" .. entry.total
                love.graphics.setFont(self.rowFont)
                Theme.set(entry.complete and Theme.muted or Theme.accentAmber,
                    entry.complete and 0.6 or 1)
                love.graphics.print(label, r.x + r.w - 12 - self.rowFont:getWidth(label), r.y + 11)
            end
        end
    end

    if #self.entries > MAX_ROWS then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted, 0.7)
        local hint = (self.scroll + MAX_ROWS) .. " of " .. #self.entries
        love.graphics.print(hint, self.listX, self.boxY + CONTENT_TOP + MAX_ROWS * (ROW_H + ROW_GAP) + 6)
    end
end

function Book:drawEntry()
    local entry = self:current()
    if not entry then return end
    local x, w = self.detailX, self.detailW
    local y = self.boxY + CONTENT_TOP

    -- Figure left, name and band right, the two centred on each other: the picture is the entry's
    -- heading as much as the name is, so neither sits under the other.
    self:drawToken(entry, x, y, PORTRAIT)
    local headX = x + PORTRAIT + 16
    local headW = w - PORTRAIT - 16
    local sub = TIER_LABEL[entry.tier] or ""
    if entry.kind then sub = sub .. "  ·  " .. entry.kind end
    local blockH = self.nameFont:getHeight() + 4 + self.bodyFont:getHeight()
    local headY = y + (PORTRAIT - blockH) / 2

    love.graphics.setFont(self.nameFont)
    Theme.set(Theme.ink)
    love.graphics.print(Theme.ellipsize(entry.name, self.nameFont, headW), headX, headY)
    headY = headY + self.nameFont:getHeight() + 4

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    love.graphics.print(Theme.ellipsize(sub, self.bodyFont, headW), headX, headY)
    y = y + PORTRAIT + 22

    love.graphics.setFont(self.capFont)
    Theme.set(Theme.muted)
    Theme.printTracked("KNOWN TO CARRY", x, y, w, 2)
    y = y + self.capFont:getHeight() + 12

    local rows = Bestiary.dropRows(self.player, entry.id)
    if #rows == 0 then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted, 0.8)
        -- A creature carries natural weapons only (docs/bestiary.md), so there is nothing behind it to
        -- go back for -- said plainly, because a blank panel reads as a bug.
        love.graphics.printf("Nothing it can be parted from. What it fights with is part of it.",
            x, y, w, "left")
        return
    end

    for _, row in ipairs(rows) do
        local band = Theme.gradeBand(row.depth, 8)
        if row.found then
            -- Carried out: named, in its rank's colour, with the depth it falls at.
            love.graphics.setFont(self.rowFont)
            Theme.set(band)
            love.graphics.print(Theme.ellipsize(row.name, self.rowFont, w - 70), x, y)
        else
            -- REDACTED. A struck bar the width of a name, in the rank's colour at low alpha -- so the
            -- row still says how dear the thing is and how deep it falls, and says nothing whatever
            -- about what it is. That pairing is the signal: there is something here, and it is worth
            -- this much, and you have not got it.
            Theme.set(band, 0.22)
            love.graphics.rectangle("fill", x, y + 4, w - 74, self.rowFont:getHeight() - 6, 1, 1)
            Theme.set(band, 0.75)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(x, y + self.rowFont:getHeight() / 2 + 1,
                x + w - 74, y + self.rowFont:getHeight() / 2 + 1)
            love.graphics.setLineWidth(1)
        end

        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted, row.found and 0.85 or 0.6)
        local depth = "floor " .. row.depth
        love.graphics.print(depth, x + w - self.smallFont:getWidth(depth), y + 4)

        y = y + self.rowFont:getHeight() + 10
    end

    y = y + 10
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted, 0.7)
    local left = entry.total - entry.found
    if left > 0 then
        love.graphics.printf(left == 1 and "One piece still to take off it."
            or (left .. " pieces still to take off it."), x, y, w, "left")
    else
        love.graphics.printf("Everything it carries is yours.", x, y, w, "left")
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Book:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    -- Hover moves the selection here, matching the Forge: this is a browse surface with no commit on
    -- it, so there is nothing a stray hover can fire.
    for i = 1, #self.entries do
        if inRect(self:rowRect(i), x, y) and self.sel ~= i then self.sel = i end
    end
end

function Book:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for i = 1, #self.entries do
        if inRect(self:rowRect(i), x, y) then return "hand" end
    end
    return "arrow"
end

function Book:wheelmoved(_, dy)
    self.scroll = self.scroll - dy
    self:clampScroll()
end

function Book:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for i = 1, #self.entries do
        if inRect(self:rowRect(i), x, y) then
            self.sel = i
            return
        end
    end
    if not inRect({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
end

function Book:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" or key == "w" then self:moveSelection(-1)
    elseif key == "down" or key == "s" then self:moveSelection(1)
    elseif key == "pageup" then self:moveSelection(-MAX_ROWS)
    elseif key == "pagedown" then self:moveSelection(MAX_ROWS)
    end
    return true
end

function Book:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" then self:moveSelection(-1)
    elseif button == "dpdown" then self:moveSelection(1)
    end
    return true
end

return Book
