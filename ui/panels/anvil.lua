-- The Cold Forge's panel: pick ONE piece the company is carrying and take it up a rung, free
-- (data/encounters/encounter_cold_forge.lua, models/forge.lua's Forge.grant).
--
--   local panel = Anvil.new({
--       title  = "The Cold Forge",
--       player = player,
--       onStrike = function(row) ... end,  -- row.item has been swapped for row.newItem in its cell
--       onLeave  = function() ... end,     -- walked away; nothing spent, the cell stays uncleared
--   })
--
-- IT IS THE BENCH'S SCREEN, CUT DOWN TO THE ONE QUESTION IT ASKS. The city's Forge (ui/panels/forge.lua)
-- is three categories, a scrubbable track and a three-track bill, because standing at a bench you are
-- choosing HOW FAR and WHAT IT COSTS. Out here neither of those is a question -- one rung, no bill -- so
-- what is left is the only thing still being decided: WHICH PIECE. The list and the reading beside it
-- are deliberately the same shapes that screen uses, down to the card, so the player is reading a
-- surface they already know rather than learning a road-only dialect.
--
-- THE PICK IS ITS OWN FIELD, and the mouse does not move it. Striking is irreversible and free, which
-- makes reading the other rows the whole of the decision -- so a hover lights a card with the steel
-- cursor ring and does nothing else, and the amber ring stays on the piece Strike would actually take
-- (the Reliquary's rule, ui/panels/relic_offer.lua). Click a card to pick it; Strike commits.
--
-- A PIECE THAT CANNOT TAKE THE RUNG IS LISTED, DIMMED, WEARING THE REASON. It is at its ceiling, or it
-- is fully forged -- either way it is a thing the player owns and would go looking for, and a list that
-- silently dropped it would read as the forge not seeing it. The refusal is asked of the model
-- (Forge.grantRefusal), never restated here, so what is greyed and what is refused are one answer.

local CloseButton = require("ui.close_button")
local Forge = require("models.forge")
local InputMode = require("input_mode")
local Item = require("models.item")
local Scale = require("scale")
local Sound = require("models.sound")
local Sprite = require("models.sprite")
local Theme = require("ui.theme")
local Vendor = require("models.vendor")

local Anvil = {}
Anvil.__index = Anvil

local BOX_W, BOX_H = 980, 600
local PAD = 24
local LIST_W = 360
local CARD_H, CARD_GAP, MAX_VISIBLE = 54, 6, 7
local CONTENT_TOP = 100 -- below the title and the prompt

local UP = { 0.55, 0.90, 0.58 }   -- an improvement: the bench's heal-green, kept semantic
local SHORT = { 0.88, 0.48, 0.44 } -- a rung this piece may not have

-- The icon well's tint when a piece has no art yet. Same five-way split the bench, the stash grid and
-- the shop use, so a wall of placeholder plates still reads by kind.
local TYPE_COLOR = {
    weapon = { 0.78, 0.42, 0.36 },
    armor = { 0.42, 0.55, 0.78 },
    consumable = { 0.44, 0.70, 0.50 },
    ability = { 0.57, 0.41, 0.79 },
    utility = { 0.80, 0.68, 0.38 },
}

local function pointIn(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- The refusal in words. `locked` is the only one with anything to say -- it names the class the ceiling
-- is measured on and the house that teaches it, exactly as the bench's own lock line does
-- (ForgePanel:ceilingReason), because "you have not climbed far enough" is useless without "in what".
local function refusalText(item)
    local class = Item.classOf(item)
    if not class then return "The coals will not take it." end
    local name = Item.classDisplayName(class) or class
    local vendorId = Forge.houseVendorFor(class)
    local house = vendorId and (Vendor.get(vendorId) or {}).name
    return "Grow " .. name .. " further before this rung is yours to take."
        .. (house and (" Its house is " .. house .. ".") or "")
end

-- The short tail a dimmed card wears in its right column, under the level it stands on.
local function tailFor(reason)
    if reason == "max level" then return "fully forged", "max" end
    if reason == "locked" then return "standing", "locked" end
    if reason then return "not forgeable", "locked" end
    return "one rung, free", nil
end

function Anvil.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Anvil)
    self.player = opts.player
    self.title = opts.title or "The Cold Forge"
    self.prompt = opts.prompt or "The coals hold enough for one piece. It will not be here when you come back."
    self.onStrike = opts.onStrike
    self.onLeave = opts.onLeave
    self.finished = false

    self.titleFont = Theme.display(28)
    self.nameFont = Theme.display(22)
    self.cardFont = Theme.display(16)
    self.bigFont = Theme.display(32)
    self.promptFont = Theme.body(15)
    self.bodyFont = Theme.body(13)
    self.smallFont = Theme.body(11)
    self.capFont = Theme.body(10)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.listLeft = self.boxX + PAD
    self.detailX = self.listLeft + LIST_W + PAD
    self.detailW = self.boxX + BOX_W - PAD - self.detailX

    -- Every piece the company walked in wearing, each already carrying the model's own verdict on
    -- whether the coals may touch it.
    self.rows = {}
    for _, up in ipairs(Forge.equipped(self.player)) do
        local reason = Forge.grantRefusal(self.player, up.item)
        local tail, state = tailFor(reason)
        self.rows[#self.rows + 1] = {
            up = up, item = up.item, level = up.item.level or 0,
            reason = reason, tail = tail, state = state,
        }
    end

    -- OPEN ON SOMETHING THE FORGE CAN ACTUALLY WORK, not on whatever happens to sit in the first grid
    -- cell. A panel that opened with the pick parked on a fully-forged piece would put a dead Strike
    -- button under the player's hand on a stop whose whole content is a gift.
    self.sel = 1
    for i, row in ipairs(self.rows) do
        if not row.reason then self.sel = i break end
    end
    self.scroll = 0
    self:scrollToSelection()

    self.hover = nil       -- the card under the mouse: lit in steel, and nothing more
    self.growthCache = {}
    self.mx, self.my = -1, -1

    local bw, bh, gap = 160, 44, 18
    local by = self.boxY + BOX_H - 76
    self.leaveBtn = { x = self.boxX + BOX_W / 2 - bw - gap / 2, y = by, w = bw, h = bh }
    self.strikeBtn = { x = self.boxX + BOX_W / 2 + gap / 2, y = by, w = bw, h = bh }

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

function Anvil:hasRows() return #self.rows > 0 end
function Anvil:current() return self.rows[self.sel] end

-- ---------------------------------------------------------------------------
-- The list: selection + scrolling
-- ---------------------------------------------------------------------------

function Anvil:canScroll() return #self.rows > MAX_VISIBLE end
function Anvil:visibleCount() return math.min(MAX_VISIBLE, #self.rows) end

-- The selection leads and the window follows -- never the other way round (ui/menu.lua's rule).
function Anvil:scrollToSelection()
    if not self:canScroll() then self.scroll = 0 return end
    if self.sel <= self.scroll then
        self.scroll = self.sel - 1
    elseif self.sel > self.scroll + MAX_VISIBLE then
        self.scroll = self.sel - MAX_VISIBLE
    end
    self.scroll = math.max(0, math.min(#self.rows - MAX_VISIBLE, self.scroll))
end

function Anvil:scrollBy(delta)
    if not self:canScroll() then return end
    self.scroll = math.max(0, math.min(#self.rows - MAX_VISIBLE, self.scroll + delta))
end

function Anvil:moveSelection(delta)
    if #self.rows == 0 then return end
    local before = self.sel
    self.sel = (self.sel - 1 + delta) % #self.rows + 1
    self:scrollToSelection()
    if self.sel ~= before then Sound.play("ui.move") end
end

function Anvil:pick(i)
    if i == self.sel then return end
    self.sel = i
    self:scrollToSelection()
    Sound.play("ui.move")
end

-- The card rect for row `i`, or nil when it is scrolled out of the window (which takes it out of
-- hit-testing and drawing for free).
function Anvil:cardRect(i)
    if i <= self.scroll or i > self.scroll + self:visibleCount() then return nil end
    local row = i - self.scroll - 1
    return { x = self.listLeft, y = self.boxY + CONTENT_TOP + row * (CARD_H + CARD_GAP),
        w = LIST_W, h = CARD_H }
end

-- The selected piece's whole forge path, baked once per blueprint and kept. Item.growth instantiates
-- eleven copies to build it, so it is asked for lazily -- a company carrying thirty pieces would pay
-- for twenty-nine charts nobody looked at.
function Anvil:growth()
    local row = self:current()
    if not row then return nil end
    local id = row.item.id
    if self.growthCache[id] == nil then
        self.growthCache[id] = Item.growth(id) or false
    end
    return self.growthCache[id] or nil
end

-- ---------------------------------------------------------------------------
-- The strike
-- ---------------------------------------------------------------------------

function Anvil:leave()
    if self.finished then return end
    self.finished = true
    if self.onLeave then self.onLeave() end
end

-- Take the picked piece up its one rung and swap the fresh instance into the cell it came from -- the
-- same move the bench makes, for the same reason: the level is baked at instantiate, so an upgrade is
-- a new object rather than an edit to the old one (models/item.lua's applyLevel).
function Anvil:strike()
    if self.finished then return end
    local row = self:current()
    if not row then return end
    local newItem = Forge.grant(self.player, row.item)
    if not newItem then
        -- NO SECOND SENTENCE. The reason is already standing under the stats on the picked piece's own
        -- reading, in the same colour, and it does not go away -- a flash message repeating it would be
        -- the same words twice on one screen, and the transient copy would be the one to go stale first.
        -- What a refusal owes here is only the confirmation that the key registered.
        Sound.play("ui.denied")
        return
    end
    row.up.char.inventory[row.up.cell] = newItem
    row.newItem = newItem
    self.finished = true
    Sound.play("stone.mark") -- a jeweller's hammer on a stamp: one rung, struck in
    if self.onStrike then self.onStrike(row) end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

-- A section caption in the chrome voice, with a hairline running out to the right edge of the band.
function Anvil:caption(text, x, y, w)
    love.graphics.setFont(self.capFont)
    Theme.set(Theme.muted)
    text = string.upper(text)
    local tw = 0
    for i = 1, #text do
        tw = tw + self.capFont:getWidth(text:sub(i, i))
        if i < #text then tw = tw + 2 end
    end
    Theme.printTracked(text, x, y, tw, 2)
    Theme.set(Theme.hairline)
    local rx = x + tw + 10
    if x + w > rx then
        love.graphics.rectangle("fill", rx, y + self.capFont:getHeight() / 2, x + w - rx, 1)
    end
end

-- An item's art in `box` px, centred and uniformly scaled; a tinted plate carrying its initial when
-- there is no art yet (models/sprite.lua hands back the path string rather than an Image).
function Anvil:drawIcon(item, x, y, box)
    local spr = item.sprite
    if type(spr) == "string" then spr = Sprite.load(spr) end
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, box, box, 3, 3)
    if type(spr) == "userdata" then
        local iw, ih = spr:getDimensions()
        local s = math.min((box - 8) / iw, (box - 8) / ih)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(spr, x + box / 2, y + box / 2, 0, s, s, iw / 2, ih / 2)
    else
        local tint = TYPE_COLOR[item.type] or Theme.muted
        love.graphics.setColor(tint[1], tint[2], tint[3], 0.5)
        love.graphics.rectangle("fill", x + 3, y + 3, box - 6, box - 6, 2, 2)
        local font = Theme.display(math.floor(box * 0.5))
        love.graphics.setFont(font)
        Theme.set(Theme.ink, 0.85)
        love.graphics.printf((item.name or "?"):sub(1, 1), x, y + box / 2 - font:getHeight() / 2, box, "center")
    end
    Theme.set(Theme.hairline)
    love.graphics.rectangle("line", x, y, box, box, 3, 3)
end

function Anvil:drawList()
    for i, row in ipairs(self.rows) do
        local r = self:cardRect(i)
        if r then
            local picked = (i == self.sel)
            local hovered = (self.hover == i) and not picked
            local off = (row.reason ~= nil)
            local alpha = off and 0.45 or 1

            Theme.set(picked and Theme.panel or Theme.panel2, alpha)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
            -- Two rings for two different things: the PICK wears the spotlight amber, a card merely
            -- under the mouse wears the steel cursor. A hovered card is being read, not chosen.
            love.graphics.setLineWidth((picked or hovered) and 1.5 or 1)
            if picked then Theme.set(Theme.accentAmber, alpha)
            elseif hovered then Theme.set(Theme.cursor, 0.9)
            else Theme.set(Theme.hairline, alpha) end
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(1, 1, 1, alpha)
            self:drawIcon(row.item, r.x + 8, r.y + 8, 38)

            local tx = r.x + 54
            local tw = r.w - 54 - 82
            local font, name = Theme.fitText(Theme.display, row.item.name or "?", tw, 16, 12)
            love.graphics.setFont(font)
            Theme.set(picked and Theme.accentAmber or Theme.ink, alpha)
            love.graphics.print(name, tx, r.y + 9)

            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.muted, alpha)
            love.graphics.print(Theme.ellipsize((row.item.type or "?") .. "  ·  " .. row.up.where,
                self.smallFont, tw), tx, r.y + 31)

            love.graphics.setFont(self.bodyFont)
            Theme.set(Theme.accentAmber, alpha)
            love.graphics.printf("+" .. row.level, r.x, r.y + 8, r.w - 10, "right")
            love.graphics.setFont(self.smallFont)
            if row.state == "max" then love.graphics.setColor(UP[1], UP[2], UP[3], alpha)
            elseif row.state then love.graphics.setColor(SHORT[1], SHORT[2], SHORT[3], alpha)
            else Theme.set(Theme.muted, alpha) end
            love.graphics.printf(row.tail, r.x, r.y + 31, r.w - 10, "right")
        end
    end
    self:drawScrollHints()
    love.graphics.setColor(1, 1, 1)
end

-- Carets above / below the list when there are cards out of sight, so it never silently hides itself.
function Anvil:drawScrollHints()
    if not self:canScroll() then return end
    local cx = self.listLeft + LIST_W / 2
    local first = self:cardRect(self.scroll + 1)
    local last = self:cardRect(self.scroll + self:visibleCount())
    Theme.set(Theme.muted)
    if self.scroll > 0 and first then
        love.graphics.polygon("fill", cx - 7, first.y - 6, cx + 7, first.y - 6, cx, first.y - 13)
    end
    if last and self.scroll + self:visibleCount() < #self.rows then
        local by = last.y + last.h
        love.graphics.polygon("fill", cx - 7, by + 6, cx + 7, by + 6, cx, by + 13)
    end
end

-- What one stat does across the rung, as a TRANSITION rather than a bonus: "14 -> 16", never "+2" on
-- its own. The number the player is about to be carrying is the number they came here for.
function Anvil:drawStatRows(growth, x, y, level)
    local stats = growth and growth.stats or {}
    if #stats == 0 then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.print("This piece has no scaling stat to chart.", x, y + 6)
        return
    end

    local pitch, shown = 26, math.min(#stats, 5)
    for i = 1, shown do
        local s = stats[i]
        local ry = y + (i - 1) * pitch
        local from, to = s.values[level], s.values[level + 1]
        local delta = (from and to) and (to - from) or 0

        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.print(Theme.ellipsize(s.label, self.bodyFont, 150), x, ry)

        Theme.set(Theme.ink)
        love.graphics.print(tostring(from or "-"), x + 156, ry)
        Theme.set(Theme.hairline)
        love.graphics.print("->", x + 196, ry)
        if delta > 0 then love.graphics.setColor(UP[1], UP[2], UP[3]) else Theme.set(Theme.ink) end
        love.graphics.print(tostring(to or "-"), x + 222, ry)
        if delta > 0 then
            love.graphics.setFont(self.smallFont)
            love.graphics.setColor(UP[1], UP[2], UP[3])
            love.graphics.print("+" .. delta, x + 264, ry + 3)
        end
    end

    if #stats > shown then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted)
        love.graphics.print("+" .. (#stats - shown) .. " more", x, y + shown * pitch + 2)
    end
end

function Anvil:drawDetail()
    local row = self:current()
    if not row then return end
    local x, w = self.detailX, self.detailW
    local y = self.boxY + CONTENT_TOP

    self:drawIcon(row.item, x, y, 56)
    local font, name = Theme.fitText(Theme.display, row.item.name or "?", w - 70, 22, 15)
    love.graphics.setFont(font)
    Theme.set(Theme.ink)
    love.graphics.print(name, x + 70, y + 6)
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    love.graphics.print(Theme.ellipsize((row.item.type or "?") .. "  ·  carried by " .. row.up.where,
        self.bodyFont, w - 70), x + 70, y + 34)

    y = y + 78
    self:caption("this rung", x, y, w)
    y = y + 22

    -- The transition, in the grammar every forecast in this game uses: where it stands, and where the
    -- strike leaves it. A refused piece prints the same pair with its second half in the refusal colour
    -- instead of the improvement green, so the reading keeps its shape whether or not the coals can be
    -- spent on this one -- what changes is the colour and the sentence under the stats, not the layout.
    local from = "+" .. row.level
    local to = "+" .. math.min(row.level + 1, Item.MAX_LEVEL)
    love.graphics.setFont(self.bigFont)
    Theme.set(Theme.ink)
    love.graphics.print(from, x, y)
    local fw = self.bigFont:getWidth(from)
    Theme.set(Theme.hairline)
    love.graphics.print("->", x + fw + 12, y + 4)
    local aw = self.bigFont:getWidth("->")
    if row.reason then love.graphics.setColor(SHORT[1], SHORT[2], SHORT[3])
    else love.graphics.setColor(UP[1], UP[2], UP[3]) end
    love.graphics.print(row.reason == "max level" and "max" or to, x + fw + 20 + aw, y)

    -- The standing this ceiling is measured against, which is the one number that explains a dimmed row.
    local ceiling = Forge.ceilingFor(self.player, row.item)
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf(ceiling < Item.MAX_LEVEL
        and ("bench ceiling +" .. ceiling .. "   ·   fully forged at +" .. Item.MAX_LEVEL)
        or ("fully forged at +" .. Item.MAX_LEVEL), x, y + 12, w, "right")

    -- WHAT THE RUNG BUYS IS ONLY DRAWN WHERE THERE IS A RUNG. A fully forged piece has no next level to
    -- chart, and the naive clamp -- read the step below the top so the table has two columns to print --
    -- quotes the gain the player ALREADY BOUGHT as though the coals were about to hand it over. A
    -- LOCKED piece keeps its table: that rung is real and priced in standing rather than gone, and what
    -- it would buy is exactly the argument for going and earning it.
    if row.reason ~= "max level" then
        y = y + 54
        self:caption("what it buys", x, y, w)
        y = y + 24
        self:drawStatRows(self:growth(), x, y, row.level)
    end

    if row.reason then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(SHORT[1], SHORT[2], SHORT[3])
        love.graphics.printf(row.reason == "max level"
            and ((row.item.name or "It") .. " has no rung left to take.")
            or refusalText(row.item), x, self.boxY + BOX_H - 168, w, "left")
    end
end

function Anvil:drawButton(b, label, enabled, accent)
    local hovered = pointIn(b, self.mx, self.my)
    Theme.set(hovered and enabled and Theme.panel or Theme.panel2, enabled and 1 or 0.5)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(enabled and 1.5 or 1)
    Theme.set(enabled and accent or Theme.hairline, enabled and 1 or 0.5)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.promptFont)
    Theme.set(enabled and accent or Theme.muted, enabled and 1 or 0.5)
    love.graphics.printf(label, b.x, b.y + b.h / 2 - self.promptFont:getHeight() / 2, b.w, "center")
end

function Anvil:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.plate(self.boxX, self.boxY, BOX_W, BOX_H, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")
    love.graphics.setFont(self.promptFont)
    Theme.set(Theme.muted)
    love.graphics.printf(self.prompt, self.boxX + PAD, self.boxY + 58, BOX_W - PAD * 2, "center")

    if self:hasRows() then
        self:drawList()
        self:drawDetail()
    else
        love.graphics.setFont(self.promptFont)
        Theme.set(Theme.muted)
        love.graphics.printf("Nobody is carrying anything a rung would improve.",
            self.boxX + PAD, self.boxY + 240, BOX_W - PAD * 2, "center")
    end

    local row = self:current()
    self:drawButton(self.leaveBtn, "Leave", true, Theme.muted)
    self:drawButton(self.strikeBtn, "Strike", row ~= nil and row.reason == nil, Theme.accentAmber)

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf(InputMode.isGamepad()
        and "D-pad up/down: pick a piece    A: strike    B: leave"
        or "Click a piece to pick it    Enter: strike    Esc: leave",
        self.boxX, self.boxY + BOX_H - 28, BOX_W, "center")

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Anvil:update(dt) end

function Anvil:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    self.hover = nil
    for i = 1, #self.rows do
        if pointIn(self:cardRect(i), x, y) then self.hover = i break end
    end
end

function Anvil:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if pointIn(self.leaveBtn, x, y) then return "hand" end
    if pointIn(self.strikeBtn, x, y) then return "hand" end
    for i = 1, #self.rows do
        if pointIn(self:cardRect(i), x, y) then return "hand" end
    end
    return "arrow"
end

function Anvil:wheelmoved(dx, dy)
    self:scrollBy(-dy)
end

function Anvil:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:leave() return end
    if pointIn(self.leaveBtn, x, y) then self:leave() return end
    if pointIn(self.strikeBtn, x, y) then self:strike() return end
    for i = 1, #self.rows do
        if pointIn(self:cardRect(i), x, y) then self:pick(i) return end
    end
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:leave() end
end

function Anvil:keypressed(key)
    if key == "escape" then self:leave()
    elseif key == "up" or key == "w" then self:moveSelection(-1)
    elseif key == "down" or key == "s" then self:moveSelection(1)
    elseif key == "pageup" then self:moveSelection(-self:visibleCount())
    elseif key == "pagedown" then self:moveSelection(self:visibleCount())
    elseif key == "return" or key == "kpenter" or key == "space" then self:strike()
    end
end

function Anvil:gamepadpressed(_, button)
    if button == "b" then self:leave()
    elseif button == "dpup" then self:moveSelection(-1)
    elseif button == "dpdown" then self:moveSelection(1)
    elseif button == "a" or button == "start" then self:strike()
    end
end

return Anvil
