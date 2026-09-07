-- Settings screen: the player's preferences, one row per option in models/settings.lua.
--
-- The list is generated from Settings.defs rather than written out here, so adding an option is a
-- data edit and this file never grows. Rows are ui/menu.lua's setting shape (label left, value
-- right), which is what gets the screen mouse, keyboard and gamepad for free -- click a row, or
-- Enter/left/right on it, and it flips.
--
-- Every change is written to disk the moment it is made. A preferences screen with an unsaved state
-- is a screen that can lie to you, and there is no Apply button here to make the distinction
-- meaningful.
--
--   State.switch(require("states.settings"), previousState)   -- Back/Esc returns there
--
-- `previousState` is optional and defaults to the main menu, which is the only door into this screen
-- today. It is a parameter anyway because the second one -- a pause menu, a hub key -- should not
-- have to strand the player at the title screen to get here.

local State = require("states")
local SettingsMenu = require("ui.settings_menu")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")

local settings = {}

local titleFont = Theme.display(40)
local bodyFont = Theme.body(16)
local rowFont = Theme.display(20)

local TITLE_Y = 84
local ROW_W, ROW_H, ROW_SPACING = 620, 42, 8
local LIST_TOP = 156

-- The description and the input hint are anchored to the BOTTOM of the screen, and the description's
-- band is RESERVED -- measured from the longest option's prose (SettingsMenu.descriptionHeight), so
-- it is the same size whichever row is highlighted. The list is then capped to the rows that fit
-- ABOVE that band and scrolls for the rest, rather than being given the whole screen and trusted not
-- to use it.
--
-- Both halves of that are scar tissue. The description used to trail the last row, which worked at
-- three options and collided with the hint the moment the three volume sliders arrived. Anchoring it
-- to the bottom fixed that and left the list free to grow downward INTO it instead -- which is what
-- the eighth option did, printing the prose across the Back row. Reserving the band and capping the
-- list is the version where adding an option can only ever cost a visible row, never overprint a
-- paragraph.
local HINT_Y = Scale.HEIGHT - 40
local DESC_GAP = 14 -- clear air between the last row and the prose

local widget
local descY -- top of the reserved description band; measured in enter()

local function backToPrevious()
    State.switch(settings.previous or require("states.menu"))
end

-- Note the `self` first parameter. State.switch calls `state.enter(state, ...)`, so the state's own
-- table always arrives ahead of the caller's arguments (states/init.lua). Written as `enter(previous)`
-- this screen took ITSELF as the previous state and Back switched to settings again -- an inescapable
-- options menu. Every state's enter must lead with self, whether or not it uses it.
function settings.enter(self, previous)
    settings.previous = previous

    descY = HINT_Y - SettingsMenu.descriptionHeight(bodyFont, ROW_W) - 12

    -- How many rows the space above the band holds. Row n runs from LIST_TOP + (n-1)*pitch to
    -- +ROW_H, so the count is the span plus one spacing over the pitch. Floored at three so a screen
    -- squeezed by an implausibly long description still shows a list rather than a caret.
    local pitch = ROW_H + ROW_SPACING
    local span = (descY - DESC_GAP) - LIST_TOP
    local maxVisible = math.max(3, math.floor((span + ROW_SPACING) / pitch))

    widget = SettingsMenu.build(backToPrevious, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = LIST_TOP,
        maxVisible = maxVisible,
        font = rowFont,
    })
end

function settings.update(dt)
    widget:update(dt)
end

function settings.draw()
    -- Fill the logical area explicitly: letterbox bars are cleared to black, so setBackgroundColor
    -- (which paints the whole real window) can't be used here. Mirrors states/menu.lua.
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Settings", 0, TITLE_Y, Scale.WIDTH, "center")

    widget:draw()

    -- What the highlighted option actually buys, in the column the rows occupy so the prose lines up
    -- with what it describes. Only the selected row's line shows -- printing all of them would turn a
    -- short list of switches into a wall of prose.
    local item = widget:selectedItem()
    if item and item.description then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf(item.description, Scale.WIDTH / 2 - ROW_W / 2, descY, ROW_W, "left")
    end

    love.graphics.setFont(bodyFont)
    Theme.set(Theme.muted)
    local hint = InputMode.isGamepad()
        and "D-pad: move    A / Left / Right: change    B: back"
        or "Arrows: move    Enter / Left / Right: change    Esc: back"
    love.graphics.printf(hint, 0, HINT_Y, Scale.WIDTH, "center")
    love.graphics.setColor(1, 1, 1)
end

function settings.mousemoved(x, y)
    widget:mousemoved(x, y)
end

-- Hand over a row, arrow elsewhere (see ui/cursor.lua).
function settings:cursorKind(x, y)
    return widget:mouseOverItem(x, y) and "hand" or "arrow"
end

function settings.mousepressed(x, y, button)
    widget:mousepressed(x, y, button)
end

-- Only does anything when the option list has outgrown the space above the description band; a list
-- that fits is not scrollable and the wheel is a no-op (ui/menu.lua's scrollBy).
function settings.wheelmoved(dx, dy)
    widget:wheelmoved(dx, dy)
end

function settings.keypressed(key)
    if key == "escape" then return backToPrevious() end
    widget:keypressed(key)
end

function settings.gamepadpressed(joystick, button)
    if button == "b" then return backToPrevious() end
    widget:gamepadpressed(joystick, button)
end

return settings
