-- Reusable vertical menu widget.
--
-- Handles mouse, keyboard, and gamepad navigation so every UI screen gets all
-- three input methods for free. Construct with a list of items and forward the
-- relevant LÖVE callbacks to it:
--
--   local Menu = require("ui.menu")
--   local menu = Menu.new({
--       { label = "Start Game", action = function() ... end },
--       { label = "Exit",       action = function() love.event.quit() end },
--   })
--
-- A row may carry `isNew = true`, which puts the red unseen dot in its top-right corner (ui/glyphs.lua)
-- -- the shop's Buy list wears it on stock a quest has just opened. The flag is read at draw time, so
-- the host clears it the moment the row is looked at without rebuilding the menu.
--
-- A row may also carry a `value` -- a string, or a function returning one -- which turns it from a
-- button into a SETTING: the label sits left, the value right, and left/right (or the d-pad's
-- horizontal axis) work it as well as Enter does. `adjust(dir)` handles a row with more than two
-- states; without one, both directions just run `action`, which is all a toggle needs. The value is
-- read at draw time rather than baked into the label, so flipping a preference needs no rebuild.
-- states/settings.lua is the whole of it in practice.
--
--   -- in your state:
--   menu:update(dt)
--   menu:draw()
--   menu:mousemoved(x, y)
--   menu:mousepressed(x, y, button)
--   menu:keypressed(key)
--   menu:gamepadpressed(joystick, button)

local Scale = require("scale")
local Sound = require("models.sound")
local Glyphs = require("ui.glyphs") -- unseenDot: the red "not looked at yet" mark on a row
local Theme = require("ui.theme")

local Menu = {}
Menu.__index = Menu

local DEFAULTS = {
    buttonWidth = 260,
    buttonHeight = 60,
    spacing = 24,
    startY = nil,           -- nil = vertically centered
    centerX = nil,          -- nil = horizontally centered on the window
    axisThreshold = 0.5,    -- analog stick deflection needed to register a move
}

local VALUE_PAD = 18 -- inset of a setting row's label and value from its button border

-- A setting row that carries `sliderFraction`/`sliderSet` draws as a SLIDER: a thin track along the
-- bottom of the row whose fill shows the level, and a click anywhere on it sets that level. This is
-- what lets a mouse LOWER a volume -- clicking a position -- rather than only nudging it up by
-- activating the row. Both the draw and the hit-test read the track from here so they cannot drift.
local SLIDER_H = 4
local function sliderTrack(item)
    return item.x + VALUE_PAD, item.y + item.h - 9, item.w - VALUE_PAD * 2, SLIDER_H
end

function Menu.new(items, opts)
    opts = opts or {}
    local self = setmetatable({}, Menu)
    self.items = items
    self.selected = 1
    self.buttonWidth = opts.buttonWidth or DEFAULTS.buttonWidth
    self.buttonHeight = opts.buttonHeight or DEFAULTS.buttonHeight
    self.spacing = opts.spacing or DEFAULTS.spacing
    self.startY = opts.startY
    self.centerX = opts.centerX
    self.font = opts.font or Theme.display(24)
    -- The face for a header's second line (see Menu:drawHeader). Falls back to the row face, so a menu
    -- that sets no `sub` on anything never notices this exists.
    self.subFont = opts.subFont
    self.axisThreshold = opts.axisThreshold or DEFAULTS.axisThreshold
    self.axisActive = false  -- edge detection so a held stick moves one step

    -- A screen showing two menus side by side (the main menu and its debug column) must show only
    -- ONE highlighted row, or neither reads as the thing Enter will press. Unfocused menus keep
    -- their selection but draw it flat; `setFocused` moves the highlight between them.
    self.focused = true

    -- Scrolling. `maxVisible` caps how many rows are drawn at once; the rest scroll past.
    -- nil (the default) means "show everything", which is what a short fixed menu wants.
    self.maxVisible = opts.maxVisible
    self.scroll = 0 -- index of the row above the first visible one
    return self
end

-- A header row (`header = true`) is a section label: it draws as a titled divider rather than a
-- button, and still occupies a normal row slot so the uniform layout/scroll maths stay untouched.
-- Used by the shop's Buy list to band its stock per discipline.
--
-- A BARE header is inert -- navigation steps over it and the mouse cannot land on it. A header that
-- carries an `action` is a FOLD: it takes the selection like any other row, so a keyboard and a pad
-- can reach the thing a mouse would click. `collapsed` (read at draw time) points its caret.
local function interactive(item)
    return item ~= nil and (not item.header or item.action ~= nil)
end

function Menu:isSelectable(i)
    return interactive(self.items[i])
end

function Menu:hasSelectable()
    for i = 1, #self.items do if self:isSelectable(i) then return true end end
    return false
end

-- Nudge `selected` onto the nearest selectable row (searching forward, then wrapping), so it never
-- rests on a header. A no-op when the current row is already selectable, so plain menus are unaffected.
function Menu:clampSelectable()
    local count = #self.items
    if count == 0 or self:isSelectable(self.selected) then return end
    for d = 1, count do
        local fwd = (self.selected - 1 + d) % count + 1
        if self:isSelectable(fwd) then self.selected = fwd; return end
    end
end

-- How many rows are on screen at once.
function Menu:visibleCount()
    if not self.maxVisible then return #self.items end
    return math.min(self.maxVisible, #self.items)
end

function Menu:canScroll()
    return self.maxVisible ~= nil and #self.items > self.maxVisible
end

-- Clamp the scroll window, then slide it just far enough to keep `selected` inside it. The
-- selection leads and the window follows -- never the other way round.
function Menu:scrollToSelection()
    if not self:canScroll() then
        self.scroll = 0
        return
    end
    local maxScroll = #self.items - self.maxVisible
    if self.selected <= self.scroll then
        self.scroll = self.selected - 1
    elseif self.selected > self.scroll + self.maxVisible then
        self.scroll = self.selected - self.maxVisible
    end
    self.scroll = math.max(0, math.min(maxScroll, self.scroll))
end

-- Put `index` at the top of the scroll window (clamped at the end of the list), leaving the selection
-- alone. What a row that has just GROWN rows beneath it needs: a fold opened on the last visible line
-- would otherwise reveal its contents entirely off-screen, and read as having done nothing.
function Menu:scrollTopTo(index)
    if not self:canScroll() then
        self.scroll = 0
        return
    end
    local maxScroll = #self.items - self.maxVisible
    self.scroll = math.max(0, math.min(maxScroll, index - 1))
end

-- Scroll by `delta` rows without moving the selection (the mouse wheel).
function Menu:scrollBy(delta)
    if not self:canScroll() then return end
    local maxScroll = #self.items - self.maxVisible
    self.scroll = math.max(0, math.min(maxScroll, self.scroll + delta))
end

-- Is this row currently inside the scroll window?
function Menu:isVisible(index)
    return index > self.scroll and index <= self.scroll + self:visibleCount()
end

-- Recompute button rectangles, centered horizontally. Rows outside the scroll window get no
-- rect at all (`x = nil`), which takes them out of hit-testing and drawing for free.
function Menu:layout()
    local screenW = Scale.WIDTH
    local screenH = Scale.HEIGHT
    local shown = self:visibleCount()
    local totalH = shown * self.buttonHeight + (shown - 1) * self.spacing
    local startY = self.startY or (screenH / 2 - totalH / 2)
    local centerX = self.centerX or (screenW / 2)

    for i, item in ipairs(self.items) do
        if self:isVisible(i) then
            local row = i - self.scroll - 1
            item.x = centerX - self.buttonWidth / 2
            item.y = startY + row * (self.buttonHeight + self.spacing)
            item.w = self.buttonWidth
            item.h = self.buttonHeight
        else
            item.x, item.y = nil, nil
        end
    end
end

local function isInside(item, px, py)
    return item.x and px >= item.x and px <= item.x + item.w
        and py >= item.y and py <= item.y + item.h
end

-- Move the selection by delta, wrapping around the ends, dragging the scroll window along.
--
-- The blip is fired here rather than at each of the five input paths that move a selection (arrows,
-- WASD, the analog stick, a gamepad d-pad, the mouse crossing a new row), so keyboard and pad and
-- mouse cannot drift apart on which movements are audible. Silent until the file exists; see
-- models/sound.lua.
function Menu:moveSelection(delta)
    local count = #self.items
    if count == 0 or not self:hasSelectable() then return end
    local before = self.selected
    local step = (delta >= 0) and 1 or -1
    local target = (self.selected - 1 + delta) % count + 1
    -- Land on a real row: if the offset put us on a header, keep stepping the SAME direction (so up
    -- and down both feel like they moved) until a selectable row, wrapping past the ends.
    local guard = 0
    while not self:isSelectable(target) and guard < count do
        target = (target - 1 + step) % count + 1
        guard = guard + 1
    end
    self.selected = target
    self:scrollToSelection()
    if self.selected ~= before then Sound.play("ui.move") end
end

function Menu:setFocused(focused)
    self.focused = focused and true or false
end

-- The row currently under the highlight, so a screen can draw whatever belongs beside the list --
-- the settings screen's description of the option being looked at.
function Menu:selectedItem()
    return self.items[self.selected]
end

-- A row's current value as a string, or nil when it is a plain button. Read fresh every frame: a
-- setting row's value is a live reading of the preference, not a copy taken when the menu was built.
function Menu.valueOf(item)
    local value = item and item.value
    if type(value) == "function" then value = value(item) end
    if value == nil then return nil end
    return tostring(value)
end

function Menu:activate()
    local item = self.items[self.selected]
    if not interactive(item) or not item.action then return end
    -- A row with an `adjust` fires its own sound as it steps (the volume sliders play into the level
    -- they are setting), so it is not given the generic confirm on top of that.
    if not item.adjust then Sound.play("ui.confirm") end
    item.action()
end

-- Work the selected row sideways: `adjust` for a row with several states, else `action`, which is
-- everything a two-state toggle needs. A plain button ignores both directions rather than firing --
-- pressing left on "Exit To Desktop" must not exit.
function Menu:adjustSelection(dir)
    local item = self.items[self.selected]
    if not item then return end
    if item.adjust then
        item.adjust(dir)
    elseif Menu.valueOf(item) and item.action then
        item.action()
    end
end

function Menu:update(dt)
    self:layout()

    -- Analog stick navigation (left stick Y), with edge detection so holding
    -- the stick advances one item per push rather than racing through them.
    local moved = false
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            local y = joystick:getGamepadAxis("lefty")
            if y <= -self.axisThreshold then
                if not self.axisActive then self:moveSelection(-1) end
                moved = true
            elseif y >= self.axisThreshold then
                if not self.axisActive then self:moveSelection(1) end
                moved = true
            end
        end
    end
    self.axisActive = moved
end

-- A caret above / below the list when there are rows scrolled out of sight, so the list never
-- silently hides its own contents.
function Menu:drawScrollHints()
    if not self:canScroll() then return end
    local first = self.items[self.scroll + 1]
    local last = self.items[self.scroll + self:visibleCount()]
    if not (first and first.x and last and last.x) then return end

    local cx = first.x + first.w / 2
    Theme.set(Theme.muted)
    if self.scroll > 0 then
        love.graphics.polygon("fill", cx - 7, first.y - 8, cx + 7, first.y - 8, cx, first.y - 16)
    end
    if self.scroll + self:visibleCount() < #self.items then
        local by = last.y + last.h
        love.graphics.polygon("fill", cx - 7, by + 8, cx + 7, by + 8, cx, by + 16)
    end
end

-- A section band: no plate, an amber uppercase caption, and a hairline along the foot so the rows
-- beneath it read as belonging to it. Sits in an ordinary row slot, so it costs the layout nothing.
--
-- A FOLD header (one with an `action`) leads with a caret -- pointing right when its section is shut,
-- down when it is open, the disclosure mark every tree uses. Selected, it rings itself in the cursor
-- steel rather than the amber every other selected row wears: the caption is ALREADY amber, and a gold
-- ring around gold text is not a highlight. Steel here also says the same thing it says everywhere
-- else in the UI -- this is where the cursor is standing.
local CARET = 9
-- A header may carry a SECOND LINE (`sub`), muted, under its name: the shop's band rail sets the path's
-- gate there ("Knight 8 + Hunter 8"), which will not fit beside a name in a 248px rail and is a
-- different KIND of fact from the name anyway. The pair is centred in the row as one block, and the
-- name's own baseline is published back on the item (`labelY`) so a host drawing a third thing on that
-- line -- the shop's stock count -- lines up with it rather than guessing at the metrics.
function Menu:drawHeader(item, active)
    love.graphics.setFont(self.font)
    local th = self.font:getHeight()
    local sub = item.sub
    local subFont = self.subFont or self.font
    local ty = item.y + item.h / 2 - th / 2
    if sub then ty = item.y + item.h / 2 - (th + subFont:getHeight() - 3) / 2 end
    item.labelY = ty
    local lx = item.x + VALUE_PAD
    -- `noCaret` is for a header the cursor may LAND on that opens nothing -- the shop's locked bands,
    -- which are selectable so their pane can be read but have no stock to walk into (ui/panels/shop.lua).
    -- A disclosure mark on one would promise a section that is never coming.
    if item.action then
        if not item.noCaret then
            local cy = item.y + item.h / 2
            Theme.set(active and Theme.cursor or Theme.accentAmber)
            if item.collapsed then
                love.graphics.polygon("fill", lx, cy - CARET * 0.5, lx, cy + CARET * 0.5, lx + CARET * 0.8, cy)
            else
                love.graphics.polygon("fill", lx - 1, cy - CARET * 0.4, lx + CARET - 1, cy - CARET * 0.4,
                    lx + CARET * 0.5 - 1, cy + CARET * 0.45)
            end
        end
        -- The indent is taken whether the caret drew or not: a `noCaret` header in a list of ordinary
        -- ones is still a row in the same column, and a name that started 17px to the left of every
        -- other name would read as a different kind of thing rather than as one that opens nothing.
        lx = lx + CARET + 8
    end
    Theme.set(Theme.accentAmber)
    love.graphics.printf((item.label or ""):upper(), lx, ty, item.x + item.w - VALUE_PAD - lx, "left")
    if sub then
        love.graphics.setFont(subFont)
        Theme.set(Theme.muted, 0.9)
        love.graphics.printf(sub, lx, ty + th - 3, item.x + item.w - VALUE_PAD - lx, "left")
        love.graphics.setFont(self.font)
    end
    Theme.set(Theme.frame, 0.7)
    love.graphics.line(item.x, item.y + item.h - 2, item.x + item.w, item.y + item.h - 2)
    -- A shut section hides its rows, dots and all, so the band carries the mark for what is under it.
    if item.isNew then Glyphs.unseenDot(item.x + item.w - 10, item.y + 10, 4) end
    if active then
        Theme.set(Theme.cursor)
        love.graphics.rectangle("line", item.x, item.y, item.w, item.h, Theme.R, Theme.R)
    end
end

function Menu:draw()
    love.graphics.setFont(self.font)
    for i, item in ipairs(self.items) do
        if item.x and item.header then
            self:drawHeader(item, (i == self.selected) and self.focused)
        elseif item.x then
            local active = (i == self.selected) and self.focused

            -- Selected row: raised (lighter) plate + bone-gold border + gold label; unselected: an
            -- inset plate with the frame trim and ink label.
            Theme.set(active and Theme.panel or Theme.panel2)
            love.graphics.rectangle("fill", item.x, item.y, item.w, item.h, Theme.R, Theme.R)
            love.graphics.setLineWidth(active and 1.5 or 1)
            Theme.set(active and Theme.accentAmber or Theme.frame)
            love.graphics.rectangle("line", item.x, item.y, item.w, item.h, Theme.R, Theme.R)
            love.graphics.setLineWidth(1)

            -- A slider row draws its level as a filled track along the bottom edge, so the value the
            -- number states is also shown as a position the mouse can click to.
            if item.sliderFraction then
                local tx, ty2, tw, th2 = sliderTrack(item)
                local frac = math.max(0, math.min(1, item.sliderFraction() or 0))
                Theme.set(Theme.frame, 0.6)
                love.graphics.rectangle("fill", tx, ty2, tw, th2, th2 / 2, th2 / 2)
                Theme.set(Theme.accentAmber)
                love.graphics.rectangle("fill", tx, ty2, tw * frac, th2, th2 / 2, th2 / 2)
            end

            Theme.set(active and Theme.accentAmber or Theme.ink)
            local th = self.font:getHeight()
            local ty = item.y + item.h / 2 - th / 2
            local value = Menu.valueOf(item)
            if value then
                -- A setting row: label left, value right, both inset from the border. Centering the
                -- label would put every row's text in a different place relative to its value, and a
                -- column of settings is read by scanning that value column.
                love.graphics.printf(item.label, item.x + VALUE_PAD, ty, item.w - VALUE_PAD * 2, "left")
                Theme.set(Theme.accentAmber)
                love.graphics.printf(value, item.x + VALUE_PAD, ty, item.w - VALUE_PAD * 2, "right")
            else
                love.graphics.printf(item.label, item.x, ty, item.w, "center")
            end

            -- The unseen dot, top-right, drawn last so it sits over the plate and its border.
            if item.isNew then Glyphs.unseenDot(item.x + item.w - 10, item.y + 10, 4) end
        end
    end
    self:drawScrollHints()
    love.graphics.setColor(1, 1, 1)
end

-- Mouse hover updates the selection so all three input methods stay in sync, and sounds the SAME
-- cursor-move cue keyboard/pad navigation does when it lands on a NEW row -- so hovering a button is
-- audible without the two input paths drifting on which movements make a sound. Silent while the
-- pointer sits still on a row (the selection only changes on a crossing) and off the list entirely.
function Menu:mousemoved(x, y)
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) and interactive(item) then
            if self.selected ~= i then
                self.selected = i
                Sound.play("ui.move")
            end
            return
        end
    end
end

function Menu:mousepressed(x, y, button)
    if button ~= 1 then return end
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) and interactive(item) then
            self.selected = i
            -- A slider row is SET by the click position (so the mouse can go down as well as up); a
            -- plain row or toggle is activated as before.
            if item.sliderSet then
                local tx, _, tw = sliderTrack(item)
                item.sliderSet((x - tx) / tw)
            else
                self:activate()
            end
            return
        end
    end
end

-- The index of the visible row under a point, or nil. Interactivity is NOT part of the test: a caller
-- that wants to ACT on the row asks `interactive` itself (mouseOverItem, just below), while one that
-- only wants to READ it -- the shop's right-click debug menu, inspecting a locked shelf row -- wants
-- the row a header or a lock would otherwise hide from it. The index, not the item, because a host
-- keeps its own parallel row list and it is that entry, not Menu's label, that carries the payload.
function Menu:indexAt(x, y)
    for i, item in ipairs(self.items) do
        if isInside(item, x, y) then return i end
    end
    return nil
end

-- True when the point is over any visible menu item, so a state can show the hand cursor there.
function Menu:mouseOverItem(x, y)
    local i = self:indexAt(x, y)
    return i ~= nil and interactive(self.items[i])
end

-- Wheel scrolls the window without moving the selection, the way a list is expected to behave.
function Menu:wheelmoved(dx, dy)
    self:scrollBy(-dy)
end

function Menu:keypressed(key)
    if key == "up" or key == "w" then
        self:moveSelection(-1)
    elseif key == "down" or key == "s" then
        self:moveSelection(1)
    elseif key == "pageup" then
        self:moveSelection(-self:visibleCount())
    elseif key == "pagedown" then
        self:moveSelection(self:visibleCount())
    elseif key == "left" or key == "a" then
        self:adjustSelection(-1)
    elseif key == "right" or key == "d" then
        self:adjustSelection(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activate()
    end
end

function Menu:gamepadpressed(joystick, button)
    if button == "dpup" then
        self:moveSelection(-1)
    elseif button == "dpdown" then
        self:moveSelection(1)
    elseif button == "dpleft" then
        self:adjustSelection(-1)
    elseif button == "dpright" then
        self:adjustSelection(1)
    elseif button == "a" or button == "start" then
        self:activate()
    end
end

return Menu
