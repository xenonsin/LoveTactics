-- THE TWO CONTROLS THAT SIT OVER A RACK OF ITEM TILES: what is shown, and in what order.
--
--   Filter (2)     a burger toggle opening a strip of chips -- one per value, multi-select, ANDed
--                  across groups. The count rides on the button, so a shut strip never hides the fact
--                  that the rack is currently narrowed.
--   Sort: Price    a button naming the order in force, opening a radio list of the orders with a hint
--                  on each spelling out what that order PRODUCES. A menu of one-word options is a menu
--                  you learn by trying all of it, and a rack rearranges four times while you read it.
--
-- BOTH ARE A VIEW AND NOTHING HERE WRITES A LIST. `apply` hands back a reordered, thinned copy of the
-- entries it was given; the caller's own stock, stash and rows are untouched, so an order picked at a
-- counter cannot outlive the panel or reach the save.
--
-- BOTH DROPDOWNS HANG UNDER THEIR BUTTON AS AN OVERLAY, drawn after everything else (drawOverlay), so
-- a shut control costs the rack no height and an open one does not push the tiles down the screen.
-- Exactly one is open at a time: they overlap the same ground, and two open panels over a rack is a
-- rack you cannot see.
--
-- WHERE THE SHAPE CAME FROM. The Armory drew both of these first (ui/panels/party.lua's stash header)
-- and STILL KEEPS ITS OWN COPY -- its dropdowns are open exactly while its focus region is on them,
-- which is a second thing to move and is worth doing as its own change rather than riding along behind
-- a feature. The pixels, the metrics and the orders live here now; that copy is the one to delete.
--
--   local controls = PoolControls.new({
--       sorts = PoolControls.SHELF_SORTS, filters = groups,
--       smallFont = f1, tinyFont = f2, onChange = function() panel:rebuild() end })
--   controls:layout(rightEdge, y, 22, rackRect)
--   controls:draw() ... controls:drawOverlay()   -- overlay last, over the tiles

local Theme = require("ui.theme")

local PoolControls = {}
PoolControls.__index = PoolControls

local CHIP_H, CHIP_GAP, CHIP_PAD = 20, 4, 8
local SORT_ROW_H = 22
local PAD = 8

local function pointIn(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- ---------------------------------------------------------------------------
-- The orders
-- ---------------------------------------------------------------------------
--
-- Each entry is named for THE ORDER IT PRODUCES rather than for the field it reads: "Type" alone does
-- not say whether a potion sorts above a sword, so every row carries the hint that says.
--
-- `less(a, b)` compares two ENTRIES -- { item = , index = } -- so an order can read POSITION as well
-- as the item. It may be a partial order: `apply` falls back to position for anything it calls equal,
-- which keeps ties stable and makes table.sort deterministic.
--
-- The first entry in a list is the DEFAULT and carries no comparator at all: it is the list exactly as
-- its owner deals it -- the shelf's own rung order, the stash's arrival order -- which is the answer to
-- "where is the thing that was just put here" and must stay reachable in one press.
local TYPE_RANK = { weapon = 1, armor = 2, ability = 3, utility = 4, consumable = 5 }

local function byName(a, b) return (a.item.name or "") < (b.item.name or "") end

local function byType(a, b)
    local ra, rb = TYPE_RANK[a.item.type] or 9, TYPE_RANK[b.item.type] or 9
    if ra ~= rb then return ra < rb end
    return byName(a, b)
end

-- A SHELF, where the default is the ladder the house stocks in and the question the player is actually
-- asking is "what can I afford" -- so Price leads the orders that rearrange it.
PoolControls.SHELF_SORTS = {
    { id = "shelf", label = "Shelf", hint = "As the shop stocks it" },
    -- WHAT IS ON THE TICKET, not what the blueprint is worth. An entry carries the row it came from, so
    -- this reads the price the host computed and printed on the tile -- a shelf price scaled to the
    -- item's recipe tier (Vendor.priceFor) -- and falls back to the item's own worth for a rack whose
    -- rows are bare items. Sorting by a number the player cannot see is not sorting.
    { id = "price", label = "Price", hint = "Cheapest first",
        less = function(a, b)
            local pa = (a.row and a.row.entry and a.row.entry.price) or a.item.price or 0
            local pb = (b.row and b.row.entry and b.row.entry.price) or b.item.price or 0
            if pa ~= pb then return pa < pb end
            return byName(a, b)
        end },
    { id = "name", label = "Name", hint = "A to Z", less = byName },
    { id = "type", label = "Type", hint = "Weapons first, potions last", less = byType },
}

-- A STASH -- the Sell counter, and the Armory's own pool. Same five orders the Armory offers, in the
-- same words: it is the same list of things, and a player crossing the square between the two screens
-- must not have to learn a second vocabulary for one question (ui/panels/party.lua's SORTS).
PoolControls.STASH_SORTS = {
    { id = "found", label = "Found", hint = "In the order they arrived" },
    { id = "recent", label = "Recent", hint = "Newest arrivals first",
        less = function(a, b) return a.index > b.index end },
    { id = "type", label = "Type", hint = "Weapons first, potions last", less = byType },
    { id = "name", label = "Name", hint = "A to Z", less = byName },
    { id = "value", label = "Value", hint = "Costliest first",
        less = function(a, b) return (a.item.price or 0) > (b.item.price or 0) end },
}

-- A chip's words. `option` is the stored VALUE the filter matches on and keys `selected` by; `format`
-- (optional) prettifies it for display only, so nice labels never change what is compared.
local function chipLabel(filter, option)
    return (filter.format and filter.format(option)) or option
end

function PoolControls.new(opts)
    opts = opts or {}
    local self = setmetatable({}, PoolControls)
    self.smallFont = opts.smallFont or Theme.body(13)
    self.tinyFont = opts.tinyFont or Theme.body(11)
    self.onChange = opts.onChange
    self.sorts = opts.sorts or PoolControls.SHELF_SORTS
    self.sortIndex = 1
    self.sortCursor = 1
    self.filterCursor = 1
    self.open = nil -- "filters", "sort", or nil
    self:setFilters(opts.filters)
    return self
end

-- Hand over the filter groups, or nil for a rack with nothing worth filtering. A group is
-- { label, options, selected, valueOf, format } -- the same shape the Armory's strip takes.
--
-- SELECTIONS SURVIVE A REBUILD when the same option is still on offer, and only then: a shelf whose
-- stock changed under a "Type: armor" chip that no longer matches anything would show an empty rack
-- and a lit filter button, with nothing on the strip to explain it.
function PoolControls:setFilters(groups)
    local held = {}
    for _, f in ipairs(self.filters or {}) do
        for value in pairs(f.selected or {}) do held[f.label .. "\0" .. tostring(value)] = true end
    end
    for _, f in ipairs(groups or {}) do
        f.selected = f.selected or {}
        for _, option in ipairs(f.options or {}) do
            if held[f.label .. "\0" .. tostring(option)] then f.selected[option] = true end
        end
    end
    self.filters = (groups and #groups > 0) and groups or nil
    if not self.filters then self.filterCursor = 1 end
    if self.open == "filters" and not self.filters then self.open = nil end
end

-- ---------------------------------------------------------------------------
-- The view: what the rack shows, and in what order
-- ---------------------------------------------------------------------------

-- Does `item` survive the strip? It must pass EVERY group, so "Type: weapon" + "Class: duelist"
-- narrows to duellist weapons. A group with nothing picked narrows nothing.
function PoolControls:passes(item)
    if not (self.filters and item) then return true end
    for _, f in ipairs(self.filters) do
        if f.valueOf and next(f.selected or {}) ~= nil then
            local v = f.valueOf(item)
            if not (v ~= nil and f.selected[v]) then return false end
        end
    end
    return true
end

function PoolControls:sortSpec() return self.sorts[self.sortIndex or 1] or self.sorts[1] end

-- Is anything actually narrowing or reordering the list right now? What a caller asks before it tells
-- the player an empty rack is empty: "nothing for sale" and "nothing that passes your filter" are two
-- different answers, and only one of them is the shop's fault.
function PoolControls:isNarrowed() return self:activeCount() > 0 end
function PoolControls:isReordered() return (self.sortIndex or 1) > 1 end

function PoolControls:activeCount()
    local n = 0
    for _, f in ipairs(self.filters or {}) do
        for _ in pairs(f.selected or {}) do n = n + 1 end
    end
    return n
end

-- `rows` in, a thinned and reordered copy out. Each row is anything at all as long as `itemOf` can get
-- an item off it (default: `row.item`), and the row objects themselves come back untouched -- the
-- caller's press, price and transaction paths all still hold the row they were built with.
function PoolControls:apply(rows, itemOf)
    itemOf = itemOf or function(row) return row.item end
    local spec = self:sortSpec()
    if not self.filters and not (spec and spec.less) then return rows end

    local entries = {}
    for i, row in ipairs(rows or {}) do
        local item = itemOf(row)
        if self:passes(item) then
            entries[#entries + 1] = { item = item or {}, index = i, row = row }
        end
    end
    if spec and spec.less then
        table.sort(entries, function(a, b)
            if spec.less(a, b) then return true end
            if spec.less(b, a) then return false end
            return a.index < b.index -- a partial order still has to be a total one for table.sort
        end)
    end
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.row end
    return out
end

-- ---------------------------------------------------------------------------
-- Where they sit
-- ---------------------------------------------------------------------------

-- Place both buttons so the pair's right edge sits at `edge`, on the line `y` at height `h`, with the
-- dropdowns hung under them over `area` (the rack's rect: they are pulled back inside it rather than
-- allowed to overhang). Returns the x the pair starts at, so a caller can put a label to its left.
function PoolControls:layout(edge, y, h, area)
    self.area = area
    local iconW, gap = 12, 6

    if self.filters then
        local w = PAD + iconW + gap + self.smallFont:getWidth("Filter (00)") + PAD
        self.filterBtn = { x = edge - w, y = y, w = w, h = h }
        edge = self.filterBtn.x - 6
    else
        self.filterBtn = nil
        self.filterChips = nil
    end

    local textW = 0
    for _, spec in ipairs(self.sorts) do
        textW = math.max(textW, self.smallFont:getWidth("Sort: " .. spec.label))
    end
    local sw = PAD + iconW + gap + textW + PAD
    self.sortBtn = { x = edge - sw, y = y, w = sw, h = h }

    -- The sort menu is as wide as its widest row and never wider than the rack it covers, hung from
    -- the button's left edge and pulled back inside the rack if it would overhang.
    local rowW = 0
    for _, spec in ipairs(self.sorts) do
        rowW = math.max(rowW, 20 + self.smallFont:getWidth(spec.label) + 14 + self.tinyFont:getWidth(spec.hint))
    end
    local menuW = math.min(math.max(rowW + PAD * 2 + 8, sw), area.w)
    local mx = math.max(area.x, math.min(self.sortBtn.x, area.x + area.w - menuW))
    local my = y + h + 4
    self.sortRows = {}
    for i in ipairs(self.sorts) do
        self.sortRows[i] = { x = mx + PAD, y = my + PAD + (i - 1) * SORT_ROW_H, w = menuW - PAD * 2, h = SORT_ROW_H }
    end
    self.sortRect = { x = mx, y = my, w = menuW, h = #self.sorts * SORT_ROW_H + PAD * 2 }

    if self.filters then
        -- The strip spans the rack it narrows rather than hanging off its button: chips wrap, and a
        -- band of them measured off a 90px toggle would be a column of one chip per line.
        local dx = area.x
        local dy = y + h + 4
        local bottom = self:layoutChips(dx + PAD, dy + PAD, area.w - PAD * 2)
        self.dropdownRect = { x = dx, y = dy, w = area.w, h = (bottom - dy) + PAD }
    end
    return self.sortBtn.x
end

-- Flow every group's chips into the band, wrapping at `w`, recording the ragged grid they land on
-- (row/col per chip) so a keyboard and a pad can walk it. Each group's label sits inline at the left
-- of its first row, so the strip stays a short block rather than a stack of headers.
function PoolControls:layoutChips(x, y, w)
    local labelW = 0
    for _, filter in ipairs(self.filters) do
        labelW = math.max(labelW, self.tinyFont:getWidth(filter.label) + 10)
    end
    self.chipLabelX = x
    self.filterChips = {}
    local chipX0 = x + labelW
    local cx, cy, row, col = chipX0, y, 1, 0

    for gi, filter in ipairs(self.filters) do
        filter.selected = filter.selected or {}
        if gi > 1 then
            if col > 0 then cy = cy + CHIP_H + CHIP_GAP; row = row + 1 end
            cx, col = chipX0, 0
        end
        filter.labelY = cy
        for _, option in ipairs(filter.options or {}) do
            local cw = self.tinyFont:getWidth(chipLabel(filter, option)) + CHIP_PAD * 2
            if col > 0 and cx + cw > x + w then
                cx, cy, col, row = chipX0, cy + CHIP_H + CHIP_GAP, 0, row + 1
            end
            col = col + 1
            self.filterChips[#self.filterChips + 1] = {
                group = gi, option = option, row = row, col = col,
                x = cx, y = cy, w = cw, h = CHIP_H,
            }
            cx = cx + cw + CHIP_GAP
        end
    end
    self.filterCursor = math.max(1, math.min(#self.filterChips, self.filterCursor or 1))
    return cy + CHIP_H
end

-- ---------------------------------------------------------------------------
-- Opening, shutting, choosing
-- ---------------------------------------------------------------------------

function PoolControls:isOpen() return self.open ~= nil end

function PoolControls:close() self.open = nil end

function PoolControls:toggle(which)
    if which == "filters" and not self.filters then return end
    if self.open == which then self.open = nil return end
    self.open = which
    if which == "sort" then self.sortCursor = self.sortIndex or 1 end
end

function PoolControls:setSort(i)
    if not self.sorts[i] then return end
    self.sortIndex, self.sortCursor = i, i
    if self.onChange then self.onChange(self) end
end

-- Flip one chip. Toggling never touches the others: a rack narrowed to "weapon + armor" is an ordinary
-- thing to want, and reaching it must not cost a trip through a cycler.
function PoolControls:toggleChip(i)
    local chip = self.filterChips and self.filterChips[i]
    if not chip then return end
    local filter = self.filters[chip.group]
    filter.selected[chip.option] = (not filter.selected[chip.option]) or nil
    self.filterCursor = i
    if self.onChange then self.onChange(self) end
end

-- The chip nearest `chip` horizontally in row `row`. Rows are ragged (chips are label-width), so
-- "the same column" would skip about; centre distance does not.
function PoolControls:chipInRow(row, chip)
    local best, bestDist
    local cx = chip.x + chip.w / 2
    for _, other in ipairs(self.filterChips) do
        if other.row == row then
            local d = math.abs((other.x + other.w / 2) - cx)
            if not bestDist or d < bestDist then best, bestDist = other, d end
        end
    end
    return best
end

function PoolControls:moveChipCursor(dc, dr)
    local chip = self.filterChips and self.filterChips[self.filterCursor]
    if not chip then return end
    local target
    if dr ~= 0 then
        target = self:chipInRow(chip.row + dr, chip)
    else
        for _, other in ipairs(self.filterChips) do
            if other.row == chip.row and other.col == chip.col + dc then target = other end
        end
    end
    if not target then return end
    for i, other in ipairs(self.filterChips) do
        if other == target then self.filterCursor = i return end
    end
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

-- The two buttons. Drawn with the rack's own chrome; the panels they open are drawOverlay's, so a
-- caller draws its tiles between the two calls and an open dropdown lands on top of them.
function PoolControls:draw()
    if self.filterBtn then self:drawFilterButton() end
    if self.sortBtn then self:drawSortButton() end
end

function PoolControls:drawOverlay()
    if self.open == "filters" then self:drawChips() end
    if self.open == "sort" then self:drawSortMenu() end
end

function PoolControls:drawFilterButton()
    local r = self.filterBtn
    local active = self:activeCount()
    Theme.set(self.open == "filters" and Theme.panel or Theme.panel2)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    Theme.set(active > 0 and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)

    local bx, barW = r.x + PAD, 12
    Theme.set(Theme.ink)
    for k = 0, 2 do
        love.graphics.rectangle("fill", bx, r.y + 6 + k * 4, barW, 2, 1, 1)
    end
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.ink)
    local label = active > 0 and ("Filter (" .. active .. ")") or "Filter"
    love.graphics.print(label, bx + barW + 6, r.y + (r.h - self.smallFont:getHeight()) / 2)
    love.graphics.setColor(1, 1, 1)
end

function PoolControls:drawSortButton()
    local r = self.sortBtn
    local spec = self:sortSpec()
    Theme.set(self.open == "sort" and Theme.panel or Theme.panel2)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    Theme.set(self:isReordered() and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)

    -- Three bars stepping shorter: the sort mark, a near-rhyme with the Filter burger beside it so the
    -- pair reads as two controls on one rack.
    local bx, barW = r.x + PAD, 12
    Theme.set(Theme.ink)
    for k = 0, 2 do
        love.graphics.rectangle("fill", bx, r.y + 6 + k * 4, barW - k * 4, 2, 1, 1)
    end
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.ink)
    love.graphics.print("Sort: " .. spec.label, bx + barW + 6, r.y + (r.h - self.smallFont:getHeight()) / 2)
    love.graphics.setColor(1, 1, 1)
end

function PoolControls:drawChips()
    local r = self.dropdownRect
    if not r then return end
    Theme.set(Theme.panel) -- fully opaque: the tiles beneath must not bleed through
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)

    love.graphics.setFont(self.tinyFont)
    local th = self.tinyFont:getHeight()
    for _, filter in ipairs(self.filters) do
        Theme.set(Theme.muted)
        love.graphics.print(filter.label, self.chipLabelX, (filter.labelY or r.y) + (CHIP_H - th) / 2)
    end

    for i, chip in ipairs(self.filterChips or {}) do
        local filter = self.filters[chip.group]
        local on = filter.selected[chip.option]
        -- On reads as a lit chip, off as a hollow one; the cursor is a separate ring, so a cursored
        -- chip still says whether it is picked.
        Theme.set(on and Theme.panel2 or Theme.slot)
        love.graphics.rectangle("fill", chip.x, chip.y, chip.w, chip.h, 4, 4)
        Theme.set(on and Theme.accentAmber or Theme.frame)
        love.graphics.rectangle("line", chip.x, chip.y, chip.w, chip.h, 4, 4)
        if self.filterCursor == i then
            Theme.set(Theme.cursor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", chip.x - 2, chip.y - 2, chip.w + 4, chip.h + 4, 5, 5)
            love.graphics.setLineWidth(1)
        end
        Theme.set(on and Theme.ink or Theme.muted)
        love.graphics.printf(chipLabel(filter, chip.option), chip.x, chip.y + (CHIP_H - th) / 2, chip.w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function PoolControls:drawSortMenu()
    local r = self.sortRect
    if not r then return end
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)

    local lh, hh = self.smallFont:getHeight(), self.tinyFont:getHeight()
    for i, row in ipairs(self.sortRows) do
        local spec = self.sorts[i]
        local on = (i == (self.sortIndex or 1))
        if on then
            Theme.set(Theme.panel2)
            love.graphics.rectangle("fill", row.x, row.y, row.w, row.h, 4, 4)
        end
        if self.sortCursor == i then
            Theme.set(Theme.cursor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", row.x, row.y, row.w, row.h, 4, 4)
            love.graphics.setLineWidth(1)
        end
        -- The radio dot: exactly one order is in force, and the list has to say which without leaning
        -- on the row tint alone (a cursored row is lit too).
        local cx, cy = row.x + 11, row.y + row.h / 2
        Theme.set(on and Theme.accentAmber or Theme.frame)
        love.graphics.circle(on and "fill" or "line", cx, cy, 3.5)

        love.graphics.setFont(self.smallFont)
        Theme.set(on and Theme.accentAmber or Theme.ink)
        love.graphics.print(spec.label, row.x + 22, row.y + (row.h - lh) / 2)
        love.graphics.setFont(self.tinyFont)
        Theme.set(Theme.muted)
        love.graphics.printf(spec.hint, row.x, row.y + (row.h - hh) / 2, row.w - 6, "right")
    end
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input. Every handler answers TRUE when it took the press, so a host can put one line at the top of
-- its own handler and let an open dropdown own the screen while it is up.
-- ---------------------------------------------------------------------------

function PoolControls:mousemoved(x, y)
    if self.open == "filters" then
        for i, chip in ipairs(self.filterChips or {}) do
            if pointIn(chip, x, y) then self.filterCursor = i return true end
        end
    elseif self.open == "sort" then
        for i, row in ipairs(self.sortRows or {}) do
            if pointIn(row, x, y) then self.sortCursor = i return true end
        end
    end
    return false
end

-- Is the pointer on something here that a press would do anything to? What a host asks to put the hand
-- cursor up (ui/cursor.lua): the two buttons always, and every chip or row of whichever panel is open.
function PoolControls:pointerOver(x, y)
    if pointIn(self.filterBtn, x, y) or pointIn(self.sortBtn, x, y) then return true end
    if self.open == "filters" then
        for _, chip in ipairs(self.filterChips or {}) do
            if pointIn(chip, x, y) then return true end
        end
    elseif self.open == "sort" then
        for _, row in ipairs(self.sortRows or {}) do
            if pointIn(row, x, y) then return true end
        end
    end
    return false
end

function PoolControls:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if self.filterBtn and pointIn(self.filterBtn, x, y) then self:toggle("filters") return true end
    if self.sortBtn and pointIn(self.sortBtn, x, y) then self:toggle("sort") return true end
    if self.open == "filters" then
        for i, chip in ipairs(self.filterChips or {}) do
            if pointIn(chip, x, y) then self:toggleChip(i) return true end
        end
        -- A press anywhere else shuts the strip rather than falling through to a tile under it: the
        -- panel is over the rack, and a click that both closed a menu and bought a sword would be one
        -- press doing two things.
        self.open = nil
        return true
    elseif self.open == "sort" then
        for i, row in ipairs(self.sortRows or {}) do
            if pointIn(row, x, y) then self:setSort(i); self.open = nil return true end
        end
        self.open = nil
        return true
    end
    return false
end

function PoolControls:keypressed(key)
    if not self.open then return false end
    if key == "escape" or key == "tab" then self.open = nil return true end
    if self.open == "sort" then
        if key == "up" or key == "w" then
            self.sortCursor = math.max(1, (self.sortCursor or 1) - 1)
        elseif key == "down" or key == "s" then
            self.sortCursor = math.min(#self.sorts, (self.sortCursor or 1) + 1)
        elseif key == "return" or key == "kpenter" or key == "space" then
            self:setSort(self.sortCursor)
            self.open = nil
        end
        return true
    end
    if key == "left" or key == "a" then self:moveChipCursor(-1, 0)
    elseif key == "right" or key == "d" then self:moveChipCursor(1, 0)
    elseif key == "up" or key == "w" then self:moveChipCursor(0, -1)
    elseif key == "down" or key == "s" then self:moveChipCursor(0, 1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:toggleChip(self.filterCursor) end
    return true
end

function PoolControls:gamepadpressed(_, button)
    if not self.open then return false end
    if button == "b" then self.open = nil return true end
    if self.open == "sort" then
        if button == "dpup" then self.sortCursor = math.max(1, (self.sortCursor or 1) - 1)
        elseif button == "dpdown" then self.sortCursor = math.min(#self.sorts, (self.sortCursor or 1) + 1)
        elseif button == "a" then self:setSort(self.sortCursor); self.open = nil end
        return true
    end
    if button == "dpleft" then self:moveChipCursor(-1, 0)
    elseif button == "dpright" then self:moveChipCursor(1, 0)
    elseif button == "dpup" then self:moveChipCursor(0, -1)
    elseif button == "dpdown" then self:moveChipCursor(0, 1)
    elseif button == "a" then self:toggleChip(self.filterCursor) end
    return true
end

return PoolControls
