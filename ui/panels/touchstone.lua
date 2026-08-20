-- THE TOUCHSTONE: the counter that names what the rift hands up unidentified (models/identify.lua).
--
-- A BENCH, NOT A SHELF. It takes something you already own and changes it, the way the Forge does, so
-- the right-hand column is the things you brought in, one selected, and the one thing that can be done
-- to it underneath. Not a shop grid -- there is nothing here to browse and nothing to compare, because
-- the whole point of the room is that you cannot tell these apart yet.
--
-- BUT IT IS STILL A COUNTER WITH SOMEBODY BEHIND IT, so it wears the city's shop layout: a keeper column
-- on the left carrying the portrait, the purse and the house's own line, and the work on the right. Every
-- door in this city that sells anything -- a shelf, a supper, a reading -- is a person you stand in front
-- of, and a room that laid out its offer with nobody in it would be the one counter in the city that was
-- a vending machine. Modelled on ui/panels/cafe.lua, which is the closest sibling: a vendor that keeps a
-- keeper and no shelf at all (`sells = false`).
--
-- NO SIN TINT ON THE PLACEHOLDER, and the Cafe's note says why for both of them: the seven houses each
-- own a deadly sin and colour their missing portrait with it, and this counter is not one of the seven.
-- A borrowed hue here would be the only thing in the game that ever claimed it was.
--
-- TWO LISTS BEHIND TWO TABS. The SATCHEL is what you are carrying, and it offers both verbs at one
-- figure: Identify spends the fee, Sell pays it. The symmetry puts the choice where it belongs -- SELL
-- WHEN YOU ARE BROKE, NAME IT WHEN YOU WANT THE THING -- and without the alternative the fee is a toll, a
-- click standing between a drop and the item, charged for nothing but the delay.
--
-- The SOLD tab is what she is still holding, and it offers one: Buy back, dearer than she paid
-- (models/identify.lua's BUYBACK_MARKUP). That premium is what makes the sale a decision rather than a
-- deposit -- at par the counter is a locker, and letting a piece go would cost nothing.
--
-- THE SOLD TAB IS NOT DRAWN WHILE THE SHELF IS EMPTY, and neither is the strip: one tab is not a choice.
-- A player who has never sold anything sees the room they saw before this existed, and the tab arrives
-- with the first thing on the shelf -- which is also the moment it starts meaning something.
--
-- THE BUTTONS ARE PINNED TO THE FOOT OF THE COLUMN rather than floated under the last row. The list
-- shrinks as pieces are named, and a button that slides up under a resting cursor between one click and
-- the next is a button that gets pressed by accident.
--
-- AN EMPTY LIST DRAWS NO BUTTONS. Not greyed ones: a control appears where it can be used, and a dead
-- plate over an empty list is an offer the room cannot honour. What stands there instead is the sentence
-- saying where unidentified gear comes from, which is the one thing a player looking at an empty counter
-- actually needs.
--
-- THE FEE IS QUOTED PER ROW, AND EVERY ROW SAYS WHICH FLOOR IT CAME OFF. Those two facts are one fact:
-- the bill reads the floor and never the piece (Identify.fee), so two rows on this list are quoted
-- differently and the floor beside each is the only thing on screen that says why.
--
-- Three-input + mouse-only, per project standard. The reveal takes the screen and this panel steps
-- aside under it, exactly as the Crossing does when somebody comes through -- see `onReveal` below.

local CloseButton = require("ui.close_button")
local Identify = require("models.identify")
local IdentifyReveal = require("ui.panels.identify_reveal")
local InputMode = require("input_mode")
local ItemTooltip = require("ui.item_tooltip")
local Player = require("models.player")
local Scale = require("scale")
local Sound = require("models.sound")
local Theme = require("ui.theme")
local Vendor = require("models.vendor") -- only for the keeper's name, portrait and pitch
local Sprite = require("models.sprite")

local Touchstone = {}
Touchstone.__index = Touchstone

local BOX_W, BOX_H = 880, 560
local PAD = 24
local VENDOR_W = 260
local ROW_H = 54
local ROW_GAP = 6
local ICON = 38
local MAX_ROWS = 5          -- the list scrolls past this rather than running off the column
local TAB_H = 30
local BTN_GAP = 14
local BTN_H = 52

local function inRect(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Touchstone.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Touchstone)
    self.opts = opts
    self.player = opts.player or Player.active
    self.vendorId = opts.vendor or Identify.VENDOR
    self.def = Vendor.get(self.vendorId) or {}
    self.title = opts.title or self.def.name or "The Touchstone"
    self.finished = false
    self.tab = "satchel"     -- "satchel" (what you carry) | "shelf" (what she is holding)
    self.focus = 1
    self.scroll = 0
    self.hoverRow = nil
    self.hoverBtn = nil
    self.notice = nil        -- what the last piece of work left behind, shown above the list

    -- The keeper. A missing file resolves to its own path string rather than crashing
    -- (models/sprite.lua), so the placeholder below draws until the art lands.
    self.vendorSprite = self.def.sprite and Sprite.load(self.def.sprite) or nil

    self.titleFont = Theme.display(28)
    self.nameFont = Theme.display(19)
    self.promptFont = Theme.body(15)
    self.rowFont = Theme.body(16)
    self.subFont = Theme.body(12)
    self.verbFont = Theme.display(20)
    self.feeFont = Theme.body(14)
    self.hintFont = Theme.body(13)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)

    self.colX = self.boxX + PAD
    self.colY = self.boxY + 64
    self.colBottom = self.boxY + BOX_H - 46
    self.workX = self.colX + VENDOR_W + PAD
    self.workW = self.boxX + BOX_W - PAD - self.workX

    self:refresh()
    return self
end

-- Re-read both lists and re-lay the work column around the open one. Called on open and after every act,
-- so a player who names four pieces without leaving watches the list empty out in front of them.
--
-- THE SHELF TAB IS NOT DRAWN WHILE THE SHELF IS EMPTY, and a player standing on it when the last piece
-- comes off is walked back to the satchel rather than left looking at a tab that is about to stop
-- existing. Same rule the buttons follow: a control appears where it can be used.
function Touchstone:refresh()
    self.satchel = Identify.pending(self.player)
    self.shelved = Identify.shelf(self.player)
    if self.tab == "shelf" and #self.shelved == 0 then self.tab = "satchel"; self.focus = 1 end
    self.items = (self.tab == "shelf") and self.shelved or self.satchel
    if self.focus > #self.items then self.focus = #self.items end
    if self.focus < 1 then self.focus = 1 end
    self:clampScroll()
    self:layout()
end

-- Switch lists. The cursor starts at the top of whichever list is now open rather than carrying its
-- index across -- row 4 of the satchel and row 4 of the shelf have nothing to do with each other.
function Touchstone:setTab(tab)
    if tab == self.tab then return end
    if tab == "shelf" and #self.shelved == 0 then return end
    self.tab, self.focus, self.scroll, self.notice = tab, 1, 0, nil
    Sound.play("ui.move")
    self:refresh()
end

-- What the open tab charges for its one act, per row. The satchel quotes the naming fee; the shelf
-- quotes the marked-up price of having it back (models/identify.lua's BUYBACK_MARKUP).
function Touchstone:priceOf(item)
    if self.tab == "shelf" then return Identify.buyBackPrice(item) end
    return Identify.fee(item)
end

function Touchstone:clampScroll()
    local maxScroll = math.max(0, #self.items - MAX_ROWS)
    if self.scroll > maxScroll then self.scroll = maxScroll end
    if self.scroll < 0 then self.scroll = 0 end
    -- Keep the focused row on screen: a keyboard cursor that walks off the bottom of a clipped list is
    -- a cursor the player cannot follow.
    if self.focus - 1 < self.scroll then self.scroll = self.focus - 1 end
    if self.focus > self.scroll + MAX_ROWS then self.scroll = self.focus - MAX_ROWS end
    if self.scroll < 0 then self.scroll = 0 end
end

function Touchstone:current()
    return self.items[self.focus]
end

-- Only the WORK column is measured -- the card and the keeper beside it are fixed, which is what makes
-- this room read as the same room every visit however much is in the satchel.
function Touchstone:layout()
    local n = #self.items
    local shown = math.min(n, MAX_ROWS)

    local EMPTY = "Nothing here needs naming. Whatever the rift hands up that nobody can name comes " ..
                  "back here, off an elite or out of a cache."
    local standing
    if self.tab == "shelf" then
        standing = "Sold, and not yet gone. She holds the last " .. Identify.SHELF_MAX ..
                   "; buying one back costs more than she paid for it."
    else
        standing = (n > 0)
            and "Nobody has named these yet. The stone will, for what the floor they came off is worth."
            or EMPTY
    end
    local prompt = self.notice or standing
    self.prompt = prompt

    -- WHERE THEY COME FROM, KEPT UNDER THE NOTICE ON AN EMPTY COUNTER. A notice replaces the standing
    -- line, which is right while there is still a list under it and wrong the moment there is not:
    -- naming the last husk would answer "what did I just do" and silently drop the only sentence that
    -- says how to get another, at exactly the visit where the player needs it. So on an empty counter
    -- the standing line comes back underneath.
    self.standing = (n == 0 and self.notice) and EMPTY or nil

    -- THE TAB STRIP, drawn only when there is a second list to switch to. One tab is not a choice, and a
    -- lone tab over a list is chrome that says "there could be more here" to a player for whom there
    -- cannot be.
    self.tabs = nil
    if #self.shelved > 0 then
        local w = 132
        self.tabs = {
            { key = "satchel", label = "Satchel", n = #self.satchel,
              x = self.workX, y = self.colY, w = w, h = TAB_H },
            { key = "shelf", label = "Sold", n = #self.shelved,
              x = self.workX + w + 6, y = self.colY, w = w, h = TAB_H },
        }
    end
    local top = self.colY + (self.tabs and (TAB_H + 12) or 0)

    local _, lines = self.promptFont:getWrap(prompt, self.workW)
    local promptH = math.max(1, #lines) * self.promptFont:getHeight()
    self.listY = top + promptH + 16
    self.listH = shown * ROW_H + math.max(0, shown - 1) * ROW_GAP

    self.rows = {}
    for i = 1, shown do
        self.rows[i] = {
            index = self.scroll + i,
            x = self.workX,
            y = self.listY + (i - 1) * (ROW_H + ROW_GAP),
            w = self.workW,
            h = ROW_H,
        }
    end

    -- Pinned to the foot of the column; see the header on why they do not follow the list.
    self.btnIdentify, self.btnSell, self.btnBuyBack = nil, nil, nil
    local by = self.colBottom - BTN_H
    if n > 0 then
        if self.tab == "shelf" then
            self.btnBuyBack = { x = self.workX, y = by, w = self.workW, h = BTN_H }
        else
            local w = (self.workW - BTN_GAP) / 2
            self.btnIdentify = { x = self.workX, y = by, w = w, h = BTN_H }
            self.btnSell = { x = self.workX + w + BTN_GAP, y = by, w = w, h = BTN_H }
        end
    end
end

-- ---- the acts ----------------------------------------------------------------

function Touchstone:identify()
    local item = self:current()
    if not item then return end
    local fee = Identify.fee(item)
    if (self.player.gold or 0) < fee then
        Sound.play("ui.denied")
        self.notice = "That costs " .. fee .. " gold and you have " .. (self.player.gold or 0) .. "."
        self:layout()
        return
    end

    -- ROLLED LONG AGO, NAMED NOW. The level and the blueprint were both decided the moment the piece was
    -- found (models/identify.lua), so what the reveal does is withhold a fact this panel already holds.
    -- The overshoot is asked FIRST, because naming the piece clears the seal the question is asked of.
    local floor = Identify.floorOf(item)
    local level = item.level
    local overshoot = Identify.isOvershoot(level, floor)
    if not Identify.read(self.player, item) then return end
    Player.save()

    -- THE REVEAL TAKES THE SCREEN and this panel steps aside under it rather than drawing behind it:
    -- the list is not information while the stone is being drawn across. The refresh on the way back
    -- out is what re-reads the satchel, so the row that was just named is gone when the player lands
    -- back in the room. Same seam the Crossing uses (ui/panels/hiring.lua).
    if self.opts.onReveal then
        self.opts.onReveal(IdentifyReveal.new({
            item = item,
            level = level,
            floor = floor,
            overshoot = overshoot,
            onClose = function()
                if self.opts.onRevealClosed then self.opts.onRevealClosed() end
                self.notice = (item.name or "It") .. " for " .. fee .. " gold."
                self:refresh()
            end,
        }))
    else
        self.notice = (item.name or "It") .. " for " .. fee .. " gold."
        self:refresh()
    end
end

function Touchstone:sell()
    if self.tab ~= "satchel" then return end
    local item = self:current()
    if not item then return end
    local label = item.name or "It"
    local paid, dropped = Identify.sell(self.player, item)
    if not paid then return end
    Player.save()
    Sound.play("ui.confirm")
    -- WHAT FELL OFF THE SHELF IS SAID OUT LOUD. A shelf that silently drops its oldest piece to make room
    -- is a shelf that steals; the player chose to sell, they did not choose to lose the other one.
    self.notice = label .. " sold for " .. paid .. " gold. She will hold it."
    if dropped then
        self.notice = self.notice .. "  The " .. (dropped.name or "oldest piece") .. " went to make room."
    end
    self:refresh()
end

function Touchstone:buyBack()
    if self.tab ~= "shelf" then return end
    local item = self:current()
    if not item then return end
    local price = Identify.buyBackPrice(item)
    if (self.player.gold or 0) < price then
        Sound.play("ui.denied")
        self.notice = "That costs " .. price .. " gold and you have " .. (self.player.gold or 0) .. "."
        self:layout()
        return
    end
    local label = item.name or "It"
    if not Identify.buyBack(self.player, item) then return end
    Player.save()
    Sound.play("ui.confirm")
    self.notice = label .. " back in the satchel, for " .. price .. " gold."
    self:refresh()
end

-- The one act of whichever tab is open, so Enter and the pad's A do the obvious thing on both lists
-- without the player having to know which button they are aiming at.
function Touchstone:confirm()
    if self.tab == "shelf" then self:buyBack() else self:identify() end
end

function Touchstone:close()
    if self.finished then return end
    self.finished = true
    if self.opts.onClose then self.opts.onClose() end
end

-- ---- drawing -----------------------------------------------------------------

-- The keeper's column: portrait, purse, and the house's own line. Laid out exactly as the Cafe's is, so
-- a player who has stood at one counter already knows where to look at this one.
function Touchstone:drawVendor()
    local x, y, w = self.colX, self.colY, VENDOR_W
    local h = self.colBottom - y
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)

    local portraitH = h - 132
    local pad = 12
    local px, py, pw, ph = x + pad, y + pad, w - pad * 2, portraitH - pad * 2
    if type(self.vendorSprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = self.vendorSprite:getDimensions()
        local scale = math.min(pw / sw, ph / sh)
        love.graphics.draw(self.vendorSprite, px + pw / 2, py + ph / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        -- No sin tint: this counter is not one of the seven houses. See the header.
        Theme.set(Theme.panel2)
        love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
        love.graphics.setFont(self.titleFont)
        Theme.set(Theme.ink)
        love.graphics.printf((self.def.name or "?"):sub(1, 1), px, py + ph / 2 - 20, pw, "center")
    end

    local ty = y + portraitH + 2
    love.graphics.setFont(self.nameFont)
    Theme.set(Theme.ink)
    love.graphics.printf(Theme.ellipsize(self.def.name or "The Touchstone", self.nameFont, w - 24),
        x + 12, ty, w - 24, "left")

    -- The purse. Both verbs in this room move it and a player deciding between them is deciding against
    -- this number, so it sits in the fixed corner of the panel the city already trains them to read for
    -- it -- under the portrait, exactly where the Cafe keeps theirs.
    love.graphics.setFont(self.promptFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print((self.player and self.player.gold or 0) .. " gold", x + 12, ty + 26)

    love.graphics.setFont(self.subFont)
    Theme.set(Theme.muted)
    love.graphics.printf(self.def.description or "", x + 12, ty + 54, w - 24, "left")
end

-- The strip over the work column, or nothing at all when there is only one list. Each tab carries its
-- COUNT, because the whole reason to look at the other one is whether there is anything on it -- and on
-- the shelf that count is also how close the oldest piece is to falling off (Identify.SHELF_MAX).
function Touchstone:drawTabs()
    if not self.tabs then return end
    love.graphics.setFont(self.subFont)
    for _, t in ipairs(self.tabs) do
        local open = (t.key == self.tab)
        Theme.set(open and Theme.panel2 or Theme.slot)
        love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, 3)
        Theme.set(open and Theme.accentAmber or Theme.frame, open and 0.85 or 0.6)
        love.graphics.setLineWidth(open and 1.6 or 1)
        love.graphics.rectangle("line", t.x, t.y, t.w, t.h, 3)
        love.graphics.setLineWidth(1)

        local label = t.label .. "  " .. t.n
        if t.key == "shelf" then label = label .. "/" .. Identify.SHELF_MAX end
        Theme.set(open and Theme.ink or Theme.muted)
        love.graphics.printf(label, t.x, t.y + (t.h - self.subFont:getHeight()) / 2, t.w, "center")
    end
end

function Touchstone:drawRow(r)
    local item = self.items[r.index]
    if not item then return end
    local selected = (r.index == self.focus)
    local hovered = (self.hoverRow == r.index)

    Theme.set(selected and Theme.panel2 or Theme.slot)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3)

    if selected then
        -- The MOVING selection is steel (Theme.cursor), never the warm gold: gold is the fixed
        -- spotlight in this project and a cursor wearing it reads as "live" rather than "here".
        Theme.set(Theme.cursor, 0.85)
        love.graphics.setLineWidth(1.6)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 3)
        love.graphics.setLineWidth(1)
    elseif hovered then
        Theme.set(Theme.frame, 0.7)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 3)
    end

    -- The husk's icon. A missing file resolves to its own path string (models/sprite.lua), so the slot
    -- draws empty rather than crashing while the art is outstanding.
    local ix, iy = r.x + 10, r.y + (r.h - ICON) / 2
    Theme.set(Theme.mount, 0.8)
    love.graphics.rectangle("fill", ix, iy, ICON, ICON, 2)
    if type(item.sprite) == "userdata" then
        Theme.set({ 1, 1, 1 })
        local sw, sh = item.sprite:getDimensions()
        local s = math.min(ICON / sw, ICON / sh)
        love.graphics.draw(item.sprite, ix + (ICON - sw * s) / 2, iy + (ICON - sh * s) / 2, 0, s, s)
    else
        Theme.set(Theme.muted, 0.5)
        love.graphics.setFont(self.rowFont)
        love.graphics.printf("?", ix, iy + (ICON - self.rowFont:getHeight()) / 2, ICON, "center")
    end

    local tx = ix + ICON + 12
    love.graphics.setFont(self.rowFont)
    Theme.set(selected and Theme.ink or Theme.muted)
    love.graphics.print(item.name or "Unidentified", tx, r.y + 9)

    love.graphics.setFont(self.subFont)
    Theme.set(Theme.muted, 0.8)
    love.graphics.print("Floor " .. Identify.floorOf(item), tx, r.y + 31)

    -- The fee, right-aligned into its own column so the figures line up down the list and two rows
    -- quoted differently read as different at a glance.
    love.graphics.setFont(self.feeFont)
    Theme.set(Theme.accentAmber, 0.9)
    love.graphics.printf(self:priceOf(item) .. "g", r.x, r.y + 18, r.w - 12, "right")
end

function Touchstone:drawButton(b, label, figure, lit, affordable)
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3)
    Theme.set(Theme.accentAmber, 0.07 + (lit and 0.07 or 0))
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3)
    Theme.set(affordable and Theme.accentAmber or Theme.frame,
        affordable and (0.8 + (lit and 0.2 or 0)) or 0.5)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 3)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(self.verbFont)
    Theme.set(affordable and Theme.ink or Theme.muted, affordable and 1 or 0.6)
    love.graphics.printf(label, b.x, b.y + 8, b.w, "center")

    love.graphics.setFont(self.subFont)
    Theme.set(Theme.muted, 0.85)
    love.graphics.printf(figure, b.x, b.y + 32, b.w, "center")
end

function Touchstone:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local bx, by = self.boxX, self.boxY
    Theme.plate(bx, by, BOX_W, BOX_H, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 18, BOX_W, "center")

    self:drawVendor()

    self:drawTabs()

    love.graphics.setFont(self.promptFont)
    Theme.set(Theme.muted)
    love.graphics.printf(self.prompt, self.workX,
        self.colY + (self.tabs and (TAB_H + 12) or 0), self.workW, "left")
    if self.standing then
        Theme.set(Theme.muted, 0.7)
        love.graphics.printf(self.standing, self.workX, self.listY, self.workW, "left")
    end

    for _, r in ipairs(self.rows) do self:drawRow(r) end

    -- How much of the list is out of sight. A clipped list that says nothing about being clipped reads
    -- as a complete list that happens to be five rows long.
    local hidden = #self.items - MAX_ROWS
    if hidden > 0 then
        love.graphics.setFont(self.subFont)
        Theme.set(Theme.muted, 0.7)
        love.graphics.printf(hidden .. " more below", self.workX, self.listY + self.listH + 4,
            self.workW, "right")
    end

    local item = self:current()
    if item then
        local price = self:priceOf(item)
        local canPay = (self.player.gold or 0) >= price
        if self.btnIdentify then
            self:drawButton(self.btnIdentify, "Identify", price .. " gold", self.hoverBtn == "identify", canPay)
            -- Sell always affords: it PAYS. Drawn lit whatever the purse says, so the one row where the
            -- player has no money still shows them the thing they can do about that.
            self:drawButton(self.btnSell, "Sell", "+" .. price .. " gold", self.hoverBtn == "sell", true)
        elseif self.btnBuyBack then
            self:drawButton(self.btnBuyBack, "Buy back", price .. " gold", self.hoverBtn == "buyback", canPay)
        end
    end

    love.graphics.setFont(self.hintFont)
    Theme.set(Theme.muted, 0.6)
    local hint = "Esc leave"
    if #self.items > 0 then
        hint = (self.tab == "shelf") and "Enter buy back" or "Enter identify  ·  S sell"
        if self.tabs then hint = hint .. "  ·  Left/Right switch list" end
        hint = hint .. "  ·  Esc leave"
    end
    love.graphics.printf(hint, bx, by + BOX_H - 30, BOX_W, "center")

    self.closeButton:draw()

    -- The hovered row's full sheet, which for a husk is its type, its one line and the floor it came
    -- off -- and nothing else, because a husk carries nothing else (models/identify.lua).
    if InputMode.isMouse() and self.hoverRow and self.items[self.hoverRow] then
        ItemTooltip.draw(self.items[self.hoverRow], self.mx or 0, self.my or 0, Scale.WIDTH - 12)
    end
end

-- ---- input -------------------------------------------------------------------

function Touchstone:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
    self.hoverRow = nil
    for _, r in ipairs(self.rows) do
        if inRect(r, x, y) then self.hoverRow = r.index end
    end
    self.hoverBtn = nil
    if inRect(self.btnIdentify, x, y) then self.hoverBtn = "identify" end
    if inRect(self.btnSell, x, y) then self.hoverBtn = "sell" end
    if inRect(self.btnBuyBack, x, y) then self.hoverBtn = "buyback" end
end

function Touchstone:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if inRect(self.btnIdentify, x, y) or inRect(self.btnSell, x, y)
        or inRect(self.btnBuyBack, x, y) then return "hand" end
    for _, t in ipairs(self.tabs or {}) do
        if inRect(t, x, y) then return "hand" end
    end
    for _, r in ipairs(self.rows) do
        if inRect(r, x, y) then return "hand" end
    end
    return "arrow"
end

function Touchstone:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for _, t in ipairs(self.tabs or {}) do
        if inRect(t, x, y) then self:setTab(t.key) return end
    end
    for _, r in ipairs(self.rows) do
        if inRect(r, x, y) then
            self.focus = r.index
            self.notice = nil
            self:layout()
            Sound.play("ui.move")
            return
        end
    end
    if inRect(self.btnIdentify, x, y) then self:identify() return end
    if inRect(self.btnSell, x, y) then self:sell() return end
    if inRect(self.btnBuyBack, x, y) then self:buyBack() return end
    if x < self.boxX or x > self.boxX + BOX_W
        or y < self.boxY or y > self.boxY + BOX_H then
        self:close()
    end
end

function Touchstone:wheelmoved(_, dy)
    if #self.items <= MAX_ROWS then return end
    self.scroll = self.scroll - (dy or 0)
    self:clampScroll()
    self:layout()
end

function Touchstone:moveFocus(delta)
    if #self.items == 0 then return end
    local n = #self.items
    self.focus = ((self.focus - 1 + delta) % n) + 1
    self.notice = nil
    self:clampScroll()
    self:layout()
    Sound.play("ui.move")
end

-- The other list, or this one when there is no other. Left and right both flip, since with exactly two
-- there is no direction to get wrong.
function Touchstone:otherTab()
    self:setTab(self.tab == "shelf" and "satchel" or "shelf")
end

function Touchstone:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "up" then self:moveFocus(-1)
    elseif key == "down" then self:moveFocus(1)
    elseif key == "left" or key == "right" then self:otherTab()
    elseif key == "return" or key == "kpenter" or key == "space" then self:confirm()
    elseif key == "s" then self:sell()
    end
end

function Touchstone:gamepadpressed(_, button)
    if button == "b" then self:close()
    elseif button == "dpup" then self:moveFocus(-1)
    elseif button == "dpdown" then self:moveFocus(1)
    elseif button == "dpleft" or button == "dpright" then self:otherTab()
    elseif button == "a" then self:confirm()
    elseif button == "x" then self:sell()
    end
end

return Touchstone
