-- Overworld "Use Items" panel: drink a restorative draught between battles to spend a flask and top a
-- party member's pool back up, without walking all the way back to the hub. Opened from the overworld
-- (states/game.lua's Use button / U / gamepad X); a run's wounds carry across its fights, and this is
-- the paid way to undo some of them mid-quest -- a Rest tile is the only free mend.
--
-- Two columns, one cursor: the LEFT list is the company -- which is the whole roster, so it scrolls --
-- and its highlighted member is the target who drinks; the RIGHT list is every restorative that
-- company can reach (each member's grid + the shared stash, gathered by Player.partyRestoratives), and
-- it scrolls for the same reason. Confirm on the right pours the selected flask into the
-- targeted member; the item and its magnitudes come straight from the same combat helpers a battlefield
-- quaff uses (Player.useConsumableOn -> Combat.restoreResource), so a potion is worth the same here as
-- in a fight, minus the turn.
--
-- Three-input + mouse-only (see the memory): click a member to target / an item to use it; keyboard
-- (arrows + Enter, Esc); gamepad (D-pad + A, B). A clickable close X (ui/close_button.lua) closes it
-- for a mouse-only player.
--
--   local panel = Consumables.new({ player = player, onClose = fn })

local CloseButton = require("ui.close_button")
local ButtonPrompt = require("ui.button_prompt")
local InputMode = require("input_mode")
local Character = require("models.character")
local Player = require("models.player")
local Scale = require("scale")
local Theme = require("ui.theme")

local Consumables = {}
Consumables.__index = Consumables

local BOX_W = 860

-- Left (party) column geometry.
local MEMBER_W = 340
local MEMBER_H = 96
local MEMBER_GAP = 10

-- Right (potions) column: a row per gathered stack.
local ITEM_H = 56
local ITEM_GAP = 8

-- The company column shows FOUR members before it scrolls, and the box is sized from that rather
-- than the other way about. At three, a starting company already overflowed: the panel opened
-- mid-scroll with a member parked off-screen, on a screen whose whole job is comparing pools against
-- each other to pick who drinks. Deriving the height from the row means that promise survives a
-- change to either number.
local MIN_MEMBER_ROWS = 4

-- The bands above and below the two columns: title + column captions overhead, message + prompt
-- strip underneath. CARET_BAND is the sliver each column keeps clear at its head and foot for the
-- more-above / more-below caret (see drawOverflow), so an arrow never lands on a caption or on the
-- message line.
local HEAD_H, FOOT_H, CARET_BAND = 90, 72, 14

-- How tall each column may grow before it scrolls. The whole roster marches now, so both lists are
-- unbounded -- the company on the left, and on the right every flask that company is carrying -- and
-- neither can be laid out on the assumption that it fits.
local LIST_H = MIN_MEMBER_ROWS * MEMBER_H + (MIN_MEMBER_ROWS - 1) * MEMBER_GAP
local BOX_H = HEAD_H + LIST_H + FOOT_H

-- Prompt tints, matching the A=confirm / B=cancel language the other panels use.
local PROMPT_GO = { 0.55, 0.90, 0.58 }
local PROMPT_NO = { 0.95, 0.50, 0.47 }

-- Bar tint per pool: health reads warm, mana cool, stamina gold -- the same three the game leans on
-- elsewhere for HP/MP/SP.
local BAR_COLOR = {
    health = { 0.78, 0.32, 0.34 },
    mana = { 0.36, 0.56, 0.92 },
    stamina = { 0.90, 0.78, 0.36 },
}
local BAR_LABEL = { health = "HP", mana = "MP", stamina = "SP" }

-- Nil-tolerant: a scrolled-out row has no rect and can never be under the mouse.
local function pointIn(r, x, y)
    return r ~= nil and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Consumables.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Consumables)
    self.player = opts.player
    self.onClose = opts.onClose
    self.title = opts.title or "Use Items"

    self.titleFont = Theme.display(26)
    self.headFont = Theme.display(17)
    self.bodyFont = Theme.body(15)
    self.smallFont = Theme.body(13)
    self.tinyFont = Theme.body(11)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2
    self.contentY = self.boxY + HEAD_H
    self.captionY = self.contentY - CARET_BAND - 20 -- "Party" / "Potions", clear of the top caret

    self.members = (self.player and self.player.roster) or {}
    self.leftX = self.boxX + 24
    self.rightX = self.leftX + MEMBER_W + 24
    self.rightW = self.boxX + BOX_W - 24 - self.rightX

    self.target = 1        -- index into self.members: the highlighted member is who drinks
    self.itemCursor = 1    -- index into self.entries
    self.memberScroll = 0  -- first member row drawn (see memberRect)
    self.itemScroll = 0    -- first potion row drawn (see itemRect)
    self.focus = "members" -- "members" | "items"
    self.hoverMember = nil
    self.hoverItem = nil
    self.mx, self.my = 0, 0

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    self:refresh()
    return self
end

-- (Re)gather the party's restoratives and clamp the item cursor to the new length. Called on open and
-- after every use, since draining a stash stack removes it from the list.
function Consumables:refresh()
    self.entries = Player.partyRestoratives(self.player)
    if self.itemCursor > #self.entries then self.itemCursor = math.max(1, #self.entries) end
    if #self.entries == 0 then self.focus = "members" end
    self:clampScroll()
end

function Consumables:currentTarget()
    return self.members[self.target]
end

-- ---------------------------------------------------------------------------
-- Scrolling (both columns; see LIST_H)
-- ---------------------------------------------------------------------------

local function rowsIn(rowH, gap) return math.max(1, math.floor((LIST_H + gap) / (rowH + gap))) end

function Consumables:visibleMembers() return rowsIn(MEMBER_H, MEMBER_GAP) end
function Consumables:visibleItems() return rowsIn(ITEM_H, ITEM_GAP) end

function Consumables:maxMemberScroll() return math.max(0, #self.members - self:visibleMembers()) end
function Consumables:maxItemScroll() return math.max(0, #self.entries - self:visibleItems()) end

-- Drag each column's window along so the row its cursor is on stays drawn. Called after any cursor
-- move and after a refresh, which can shorten the potion list under the cursor.
function Consumables:clampScroll()
    local mv, iv = self:visibleMembers(), self:visibleItems()
    if self.memberScroll > self.target - 1 then self.memberScroll = self.target - 1
    elseif self.target > self.memberScroll + mv then self.memberScroll = self.target - mv end
    if self.itemScroll > self.itemCursor - 1 then self.itemScroll = self.itemCursor - 1
    elseif self.itemCursor > self.itemScroll + iv then self.itemScroll = self.itemCursor - iv end
    self.memberScroll = math.max(0, math.min(self:maxMemberScroll(), self.memberScroll))
    self.itemScroll = math.max(0, math.min(self:maxItemScroll(), self.itemScroll))
end

-- A caret over the head / under the foot of a column that has rows scrolled out of sight, matching
-- the pair ui/menu.lua draws around its own long lists.
--
-- An ARROW, not the count it used to print ("1 above", "2 more below"). The number was a figure no
-- decision on this screen reads -- you keep scrolling because there is more, never because there are
-- exactly two -- and two words set in a column of rows read as a row themselves, which is how a
-- hidden member came to look like a label. The caret says the one thing that is acted on: keep going
-- this way.
function Consumables:drawOverflow(x, w, scroll, total, visible)
    if total <= visible then return end
    local cx = x + w / 2
    Theme.set(Theme.muted)
    if scroll > 0 then
        local base = self.contentY - 4
        love.graphics.polygon("fill", cx - 7, base, cx + 7, base, cx, base - 8)
    end
    if total - scroll - visible > 0 then
        local base = self.contentY + LIST_H + 4
        love.graphics.polygon("fill", cx - 7, base, cx + 7, base, cx, base + 8)
    end
end

function Consumables:close()
    if self.onClose then self.onClose() end
end

-- Apply the selected flask to the targeted member. Blocked (with a spoken reason) when it would do
-- nothing -- a full pool -- so a potion is never thrown away for zero out here.
function Consumables:useSelected()
    local entry = self.entries[self.itemCursor]
    local char = self:currentTarget()
    if not (entry and char) then return end
    if not Player.canUseConsumableOn(char, entry.item) then
        local stat = Player.restorativeStat(entry.item)
        local label = BAR_LABEL[stat] or "pool"
        -- A pool the member doesn't own at all (Saber has no mana) is refused for a different reason
        -- than a topped-up one, and "already full" reads as a lie next to an absent bar.
        local res = char.stats and char.stats[stat]
        local owns = type(res) ~= "table" or (res.max or 0) > 0
        self:setMsg((char.name or "That member") .. (owns
            and ("'s " .. label .. " is already full.")
            or (" has no " .. label .. " to restore.")), false)
        return
    end
    local name = entry.item.name or "a potion"
    local amount, stat = Player.consumeRestorative(self.player, entry, char)
    self:setMsg(string.format("%s drinks %s.  +%d %s",
        char.name or "The member", name, amount, BAR_LABEL[stat] or stat), true)
    self:refresh()
end

function Consumables:setMsg(text, ok)
    self.message, self.messageOk = text, ok
end

-- ---------------------------------------------------------------------------
-- Navigation (one cursor flowing across the two columns)
-- ---------------------------------------------------------------------------

function Consumables:navigate(dc, dr)
    if self.focus == "members" then
        if dr ~= 0 and #self.members > 0 then
            self.target = math.max(1, math.min(#self.members, self.target + dr))
        elseif dc == 1 and #self.entries > 0 then
            self.focus = "items"
        end
    else -- items
        if dr ~= 0 and #self.entries > 0 then
            self.itemCursor = math.max(1, math.min(#self.entries, self.itemCursor + dr))
        elseif dc == -1 then
            self.focus = "members"
        end
    end
    self:clampScroll()
end

function Consumables:confirm()
    if self.focus == "members" then
        if #self.entries > 0 then self.focus = "items" end
    else
        self:useSelected()
    end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function Consumables:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.print("Party", self.leftX, self.captionY)
    love.graphics.print("Potions", self.rightX, self.captionY)

    self:drawMembers()
    self:drawItems()
    self:drawFooter()

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- The row's rect, or nil when it is scrolled out of the column.
function Consumables:memberRect(i)
    local slot = i - self.memberScroll
    if slot < 1 or slot > self:visibleMembers() then return nil end
    return { x = self.leftX, y = self.contentY + (slot - 1) * (MEMBER_H + MEMBER_GAP),
             w = MEMBER_W, h = MEMBER_H }
end

function Consumables:drawMembers()
    self:drawOverflow(self.leftX, MEMBER_W, self.memberScroll, #self.members, self:visibleMembers())
    for i, char in ipairs(self.members) do
        local r = self:memberRect(i)
        if r then self:drawMemberRow(i, char, r) end
    end
    love.graphics.setColor(1, 1, 1)
end

function Consumables:drawMemberRow(i, char, r)
    local targeted = (i == self.target)
    love.graphics.setColor(targeted and 0.20 or 0.15, targeted and 0.24 or 0.16,
        targeted and 0.32 or 0.21)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)

    -- Portrait chip: the sprite when the art loaded (models/sprite.lua hands back the path string
    -- otherwise), else the name's first letter -- the same fallback the loadout rail uses.
    local ps = MEMBER_H - 16
    local px, py = r.x + 8, r.y + 8
    local sprite = char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3, 0.32, 0.4)
        love.graphics.rectangle("fill", px, py, ps, ps, 5, 5)
        love.graphics.setFont(self.headFont)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, py + ps / 2 - 10, ps, "center")
    end

    local tx = px + ps + 12
    local tw = r.x + r.w - tx - 10
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.94, 0.94, 0.97)
    love.graphics.print(char.name or "?", tx, r.y + 8)

    -- HP / MP / SP bars, skipping any pool the member doesn't have (a fighter shows no MP row).
    -- Every resource stat instantiates as a table even when the blueprint authored it as 0, so the
    -- "doesn't have it" test is a max of 0, not the absence of the table (as ui/tile_tooltip.lua does).
    local by = r.y + 32
    for _, stat in ipairs(Character.RESOURCE_STATS) do
        local res = char.stats and char.stats[stat]
        if type(res) == "table" and (res.max or 0) > 0 then
            self:drawBar(tx, by, tw, stat, res.current or res.max or 0, res.max or 0)
            by = by + 18
        end
    end

    if targeted then
        love.graphics.setColor(0.95, 0.82, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setLineWidth(1)
    end
    -- Cyan focus ring only while the left column has keyboard/pad focus, so it never fights the
    -- gold target ring for meaning.
    if self.focus == "members" and i == self.target and not InputMode.isMouse() then
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x - 2, r.y - 2, r.w + 4, r.h + 4, 7, 7)
        love.graphics.setLineWidth(1)
    end
end

-- One labelled resource bar: "HP  [=====     ]  cur/max".
function Consumables:drawBar(x, y, w, stat, cur, max)
    love.graphics.setFont(self.tinyFont)
    love.graphics.setColor(0.6, 0.63, 0.72)
    love.graphics.print(BAR_LABEL[stat] or stat, x, y + 1)

    local barX = x + 26
    local barW = w - 26 - 62 -- leave room for the "cur/max" readout on the right
    if barW < 20 then barW = 20 end
    local barH = 10
    love.graphics.setColor(0.08, 0.09, 0.12)
    love.graphics.rectangle("fill", barX, y + 1, barW, barH, 3, 3)
    local frac = max > 0 and math.max(0, math.min(1, cur / max)) or 0
    local c = BAR_COLOR[stat] or { 0.7, 0.7, 0.7 }
    love.graphics.setColor(c[1], c[2], c[3])
    love.graphics.rectangle("fill", barX, y + 1, barW * frac, barH, 3, 3)
    love.graphics.setColor(0.3, 0.33, 0.4)
    love.graphics.rectangle("line", barX, y + 1, barW, barH, 3, 3)

    love.graphics.setColor(0.82, 0.85, 0.9)
    love.graphics.printf(math.floor(cur) .. "/" .. math.floor(max), barX + barW + 4, y, 58, "left")
end

-- The row's rect, or nil when it is scrolled out of the column.
function Consumables:itemRect(i)
    local slot = i - self.itemScroll
    if slot < 1 or slot > self:visibleItems() then return nil end
    return { x = self.rightX, y = self.contentY + (slot - 1) * (ITEM_H + ITEM_GAP),
             w = self.rightW, h = ITEM_H }
end

function Consumables:drawItems()
    if #self.entries == 0 then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.6, 0.63, 0.72)
        love.graphics.printf("No potions to use.", self.rightX, self.contentY + 20, self.rightW, "center")
        return
    end

    self:drawOverflow(self.rightX, self.rightW, self.itemScroll, #self.entries, self:visibleItems())
    local target = self:currentTarget()
    for i, entry in ipairs(self.entries) do
        local r = self:itemRect(i)
        if r then self:drawItemRow(i, entry, r, target) end
    end
    love.graphics.setColor(1, 1, 1)
end

function Consumables:drawItemRow(i, entry, r, target)
    local item = entry.item
    -- Dim a flask that would do the CURRENT target no good (their matching pool is full): the row
    -- is still there for another member, but it reads as spent effort on this one.
    local usable = target and Player.canUseConsumableOn(target, item)
    local cursored = (self.focus == "items" and i == self.itemCursor)

    love.graphics.setColor(cursored and 0.22 or 0.15, cursored and 0.26 or 0.16, cursored and 0.34 or 0.21)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)

    local ps = ITEM_H - 12
    local px, py = r.x + 6, r.y + 6
    local sprite = item.sprite
    local dim = usable and 1 or 0.45
    if type(sprite) == "userdata" then
        love.graphics.setColor(dim, dim, dim)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3 * dim, 0.32 * dim, 0.4 * dim)
        love.graphics.rectangle("fill", px, py, ps, ps, 5, 5)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.9 * dim, 0.9 * dim, 0.95 * dim)
        love.graphics.printf((item.name or "?"):sub(1, 1), px, py + ps / 2 - 8, ps, "center")
    end

    local tx = px + ps + 12
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.94 * dim, 0.94 * dim, 0.97 * dim)
    love.graphics.print(item.name or "?", tx, r.y + 8)

    -- "+N HP" in the pool's own tint -- what one swallow of this flask would pour.
    local stat = Player.restorativeStat(item)
    local ab = item.activeAbility or {}
    local mag = ab.healing or ab.restore or 0
    local c = BAR_COLOR[stat] or { 0.7, 0.7, 0.7 }
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(c[1] * dim + (1 - dim) * 0.5, c[2] * dim + (1 - dim) * 0.5, c[3] * dim + (1 - dim) * 0.5)
    love.graphics.print("+" .. mag .. " " .. (BAR_LABEL[stat] or stat), tx, r.y + 30)

    -- Quantity on the right, plus where it sits (a stash flask is shared; a grid flask a member
    -- is already carrying), so the player can tell a satchel potion from a carried one.
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.85, 0.87, 0.92)
    love.graphics.printf("x" .. (item.quantity or 1), r.x, r.y + 8, r.w - 12, "right")
    love.graphics.setFont(self.tinyFont)
    love.graphics.setColor(0.55, 0.58, 0.66)
    local from = entry.where == "stash" and "stash" or (entry.char and entry.char.name or "carried")
    love.graphics.printf(from, r.x, r.y + 30, r.w - 12, "right")

    if cursored then
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
        love.graphics.setLineWidth(1)
    end
end

function Consumables:drawFooter()
    if self.message then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end

    local pad = InputMode.isGamepad()
    local segments = {}
    local function add(glyph, label, color) segments[#segments + 1] = { glyph = glyph, label = label, color = color } end
    if self.focus == "items" then
        add(pad and "A" or "Enter", "Use on " .. ((self:currentTarget() and self:currentTarget().name) or "member"), PROMPT_GO)
        add(pad and "B" or "Esc", "Close", PROMPT_NO)
    else
        add(pad and "A" or "Enter", #self.entries > 0 and "Pick a potion" or "Select", PROMPT_GO)
        add(pad and "B" or "Esc", "Close", PROMPT_NO)
    end
    ButtonPrompt.draw(segments, self.boxX, self.boxY + BOX_H - 30, BOX_W, { align = "center" })
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Consumables:update() end

function Consumables:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for i = 1, #self.members do
        if pointIn(self:memberRect(i), x, y) then return "hand" end
    end
    for i = 1, #self.entries do
        if pointIn(self:itemRect(i), x, y) then return "hand" end
    end
    return "arrow"
end

function Consumables:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)
end

-- The wheel scrolls whichever column the cursor is over -- the company on the left, the flasks on the
-- right -- so a long list is reachable without first moving the keyboard focus into it.
function Consumables:wheelmoved(_, dy)
    if dy == 0 then return end
    local overLeft = self.mx >= self.leftX and self.mx <= self.leftX + MEMBER_W
    if overLeft then
        self.memberScroll = math.max(0, math.min(self:maxMemberScroll(), self.memberScroll - dy))
    else
        self.itemScroll = math.max(0, math.min(self:maxItemScroll(), self.itemScroll - dy))
    end
end

function Consumables:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end

    for i = 1, #self.members do
        if pointIn(self:memberRect(i), x, y) then
            self.target = i
            self.focus = "members"
            return
        end
    end
    for i = 1, #self.entries do
        if pointIn(self:itemRect(i), x, y) then
            self.itemCursor = i
            self.focus = "items"
            self:useSelected()
            return
        end
    end

    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then
        self:close()
    end
end

function Consumables:keypressed(key)
    if key == "escape" then
        self:close()
    elseif key == "left" or key == "a" then
        self:navigate(-1, 0)
    elseif key == "right" or key == "d" then
        self:navigate(1, 0)
    elseif key == "up" or key == "w" then
        self:navigate(0, -1)
    elseif key == "down" or key == "s" then
        self:navigate(0, 1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:confirm()
    end
end

function Consumables:gamepadpressed(_, button)
    if button == "b" then
        self:close()
    elseif button == "dpleft" then
        self:navigate(-1, 0)
    elseif button == "dpright" then
        self:navigate(1, 0)
    elseif button == "dpup" then
        self:navigate(0, -1)
    elseif button == "dpdown" then
        self:navigate(0, 1)
    elseif button == "a" then
        self:confirm()
    end
end

return Consumables
