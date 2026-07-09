-- Reusable scrolling list of the player's stashed items (models/player.lua: an unbounded list of
-- everything nobody is carrying). The companion to ui/inventory_grid.lua: the grid arranges what a
-- character holds, this holds everything else, and ui/panels/loadout.lua moves items between them.
--
-- Like the grid it is a PICK-THEN-PLACE surface -- activating a row picks that item up; the host
-- panel then places it into a grid cell. It never moves items itself, so the two widgets can't
-- disagree about who owns what: the panel performs every transfer. Dragging a row onto the grid is
-- the same transfer by another route, and is likewise driven by the panel (ui/panels/loadout.lua).
--
-- Follows the project's three-input standard and is fully mouse-only playable: click a row, or
-- click the scroll arrows (the wheel is a shortcut, never the only way); or drive the cursor with
-- arrows/D-pad + confirm, which scrolls the view to follow.
--
--   local stash = StashList.new({ x = , y = , w = , h = , stash = player.stash })
--   stash:setStash(list)
--   stash:draw(); stash:mousemoved(x, y); stash:mousepressed(x, y, button)
--   stash:wheelmoved(dy); stash:contains(x, y)
--   stash:keypressed(key); stash:gamepadpressed(joystick, button); stash:cancelPickup()

local StashList = {}
StashList.__index = StashList

local ROW_H = 40
local ROW_GAP = 4
local ARROW_H = 22 -- clickable scroll arrows above and below the rows

-- Rows moved per wheel notch. The view is only a handful of rows tall, so the usual three-line
-- scroll would throw away most of a page per click.
local SCROLL_ROWS = 2

-- Row tint per item type, matching ui/item_tooltip.lua's accent colours.
local TYPE_COLOR = {
    weapon = { 0.90, 0.58, 0.48 },
    armor = { 0.58, 0.72, 0.92 },
    consumable = { 0.52, 0.85, 0.55 },
    ability = { 0.78, 0.62, 0.96 },
    utility = { 0.92, 0.82, 0.52 },
}
local DEFAULT_COLOR = { 0.80, 0.80, 0.86 }

function StashList.new(opts)
    opts = opts or {}
    local self = setmetatable({}, StashList)
    self.x, self.y = opts.x or 0, opts.y or 0
    self.w, self.h = opts.w or 300, opts.h or 300
    self.stash = opts.stash or {}
    self.cursor = 1   -- keyboard/gamepad cursor row (1-based, into the stash list)
    self.offset = 0   -- first visible row - 1
    self.picked = nil -- the row currently picked up, or nil
    self.hover = nil
    self.focused = false
    self.nameFont = love.graphics.newFont(13)
    self.smallFont = love.graphics.newFont(11)

    -- Rows fit between the two scroll arrows.
    self.listY = self.y + ARROW_H
    self.listH = self.h - ARROW_H * 2
    self.rows = math.max(1, math.floor((self.listH + ROW_GAP) / (ROW_H + ROW_GAP)))
    self.upArrow = { x = self.x, y = self.y, w = self.w, h = ARROW_H }
    self.downArrow = { x = self.x, y = self.y + self.h - ARROW_H, w = self.w, h = ARROW_H }
    return self
end

function StashList:setStash(stash)
    self.stash = stash or {}
    self.picked = nil
    self.cursor = 1
    self.offset = 0
end

-- The list changed under us (an item was taken out or put in). Drop any pickup -- the row it named
-- may be a different item now -- and pull the cursor and scroll back into range, WITHOUT jumping
-- the view back to the top the way setStash would.
function StashList:refresh()
    self.picked = nil
    self.hover = nil
    self.cursor = math.max(1, math.min(math.max(1, self:count()), self.cursor))
    self.offset = math.max(0, math.min(self:maxOffset(), self.offset))
end

function StashList:count() return #self.stash end

-- The largest scroll offset that still fills the view (0 when everything fits).
function StashList:maxOffset()
    return math.max(0, self:count() - self.rows)
end

function StashList:scroll(delta)
    self.offset = math.max(0, math.min(self:maxOffset(), self.offset + delta))
end

-- Wheel notches, as LÖVE reports them: dy > 0 is a push away from the user, which walks the view
-- back up toward earlier rows. The host panel decides whether the pointer is over us first.
function StashList:wheelmoved(dy)
    self:scroll(-dy * SCROLL_ROWS)
end

-- Whole-widget hit test, arrows included -- the host uses it as a drop target for a dragged item.
function StashList:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

-- Keep the cursor row on screen after it moves.
function StashList:scrollToCursor()
    if self.cursor <= self.offset then
        self.offset = self.cursor - 1
    elseif self.cursor > self.offset + self.rows then
        self.offset = self.cursor - self.rows
    end
    self.offset = math.max(0, math.min(self:maxOffset(), self.offset))
end

function StashList:moveCursor(delta)
    local n = self:count()
    if n == 0 then return end
    self.cursor = math.max(1, math.min(n, self.cursor + delta))
    self:scrollToCursor()
end

-- Screen rect of the visible row holding stash index `i`, or nil if it is scrolled out of view.
function StashList:rowRect(i)
    local visible = i - self.offset
    if visible < 1 or visible > self.rows then return nil end
    return self.x, self.listY + (visible - 1) * (ROW_H + ROW_GAP), self.w, ROW_H
end

-- The stash index under a pixel, or nil.
function StashList:indexAt(px, py)
    for i = self.offset + 1, math.min(self:count(), self.offset + self.rows) do
        local rx, ry, rw, rh = self:rowRect(i)
        if rx and px >= rx and px <= rx + rw and py >= ry and py <= ry + rh then return i end
    end
    return nil
end

-- Pick up the item at row `i` (or drop the current pickup if it's the same row). The host panel
-- reads `picked` and performs the actual move.
function StashList:activate(i)
    if not i or not self.stash[i] then return end
    if self.picked == i then self.picked = nil else self.picked = i end
end

function StashList:cancelPickup()
    if self.picked ~= nil then
        self.picked = nil
        return true
    end
    return false
end

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function StashList:draw()
    -- Backing well.
    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 6, 6)
    love.graphics.setColor(self.focused and 0.60 or 0.30, self.focused and 0.70 or 0.34,
        self.focused and 0.92 or 0.42)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 6, 6)

    if self:count() == 0 then
        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(0.5, 0.52, 0.6)
        love.graphics.printf("Stash is empty", self.x, self.y + self.h / 2 - 8, self.w, "center")
        love.graphics.setColor(1, 1, 1)
        return
    end

    -- Scroll arrows, dimmed at the ends of the list (still drawn, so the column never reflows).
    love.graphics.setFont(self.smallFont)
    local canUp, canDown = self.offset > 0, self.offset < self:maxOffset()
    love.graphics.setColor(0.7, 0.74, 0.85, canUp and 0.95 or 0.25)
    love.graphics.printf("^", self.upArrow.x, self.upArrow.y + 5, self.upArrow.w, "center")
    love.graphics.setColor(0.7, 0.74, 0.85, canDown and 0.95 or 0.25)
    love.graphics.printf("v", self.downArrow.x, self.downArrow.y + 5, self.downArrow.w, "center")

    for i = self.offset + 1, math.min(self:count(), self.offset + self.rows) do
        local item = self.stash[i]
        local rx, ry, rw, rh = self:rowRect(i)
        local lifted = (self.picked == i)
        local dim = lifted and 0.5 or 1

        love.graphics.setColor(0.16, 0.17, 0.22)
        love.graphics.rectangle("fill", rx, ry, rw, rh, 5, 5)

        -- Icon square on the left: the item's art, or its initial on a type-tinted plate.
        local col = TYPE_COLOR[item.type] or DEFAULT_COLOR
        local isz = rh - 8
        local ix, iy = rx + 4, ry + 4
        local sprite = item.sprite
        if type(sprite) == "userdata" then
            love.graphics.setColor(dim, dim, dim)
            local iw, ih = sprite:getDimensions()
            local scale = math.min(isz / iw, isz / ih)
            love.graphics.draw(sprite, ix + isz / 2, iy + isz / 2, 0, scale, scale, iw / 2, ih / 2)
        else
            love.graphics.setColor(col[1] * 0.5 * dim, col[2] * 0.5 * dim, col[3] * 0.5 * dim)
            love.graphics.rectangle("fill", ix, iy, isz, isz, 4, 4)
            love.graphics.setFont(self.nameFont)
            love.graphics.setColor(dim, dim, dim)
            love.graphics.printf((item.name or "?"):sub(1, 1), ix, iy + isz / 2 - 8, isz, "center")
        end

        -- Name, plus the stack count for a bundled consumable.
        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(col[1] * dim, col[2] * dim, col[3] * dim)
        love.graphics.print(item.name or "?", ix + isz + 8, ry + 6)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.55 * dim, 0.58 * dim, 0.66 * dim)
        love.graphics.print(item.type or "", ix + isz + 8, ry + 22)
        if (item.quantity or 1) > 1 then
            love.graphics.setColor(0.85 * dim, 0.86 * dim, 0.92 * dim)
            love.graphics.printf("x" .. item.quantity, rx, ry + rh / 2 - 6, rw - 8, "right")
        end

        if lifted then
            love.graphics.setColor(0.95, 0.85, 0.35)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", rx, ry, rw, rh, 5, 5)
            love.graphics.setLineWidth(1)
        end
        if self.hover == i then
            love.graphics.setColor(0.95, 0.85, 0.55, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", rx, ry, rw, rh, 5, 5)
            love.graphics.setLineWidth(1)
        end
        if self.focused and self.cursor == i then
            love.graphics.setColor(0.6, 0.75, 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", rx - 2, ry - 2, rw + 4, rh + 4, 6, 6)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function StashList:mousemoved(x, y)
    self.hover = self:indexAt(x, y)
end

-- Returns true if the click landed on this widget (a row or a scroll arrow), so the host panel can
-- treat it as handled -- and, for a row, so it knows to run a transfer.
function StashList:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if pointIn(self.upArrow, x, y) then self:scroll(-1) return true end
    if pointIn(self.downArrow, x, y) then self:scroll(1) return true end
    local i = self:indexAt(x, y)
    if not i then return false end
    self.cursor = i
    return true, i
end

function StashList:keypressed(key)
    if key == "up" or key == "w" then self:moveCursor(-1)
    elseif key == "down" or key == "s" then self:moveCursor(1)
    elseif key == "return" or key == "kpenter" or key == "space" then return self.cursor
    end
    return nil
end

function StashList:gamepadpressed(_, button)
    if button == "dpup" then self:moveCursor(-1)
    elseif button == "dpdown" then self:moveCursor(1)
    elseif button == "a" then return self.cursor
    end
    return nil
end

return StashList
