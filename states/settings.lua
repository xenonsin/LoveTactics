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

local ROW_W, ROW_H, ROW_SPACING = 620, 46, 10
local LIST_TOP = 178

-- The description and the input hint are anchored to the BOTTOM of the screen rather than trailing
-- the list. They used to hang off the last row, which worked at three options and collided with the
-- hint the moment the three volume sliders were added -- the list grew downward into text at a fixed
-- height. Anchoring both to the bottom means adding an option can only ever eat the gap above the
-- description, which is slack, instead of silently printing two paragraphs on top of each other.
local HINT_Y = Scale.HEIGHT - 40
local DESC_H = 56 -- room for two wrapped lines of bodyFont
local DESC_Y = HINT_Y - DESC_H - 10

local widget

local function backToPrevious()
    State.switch(settings.previous or require("states.menu"))
end

-- Note the `self` first parameter. State.switch calls `state.enter(state, ...)`, so the state's own
-- table always arrives ahead of the caller's arguments (states/init.lua). Written as `enter(previous)`
-- this screen took ITSELF as the previous state and Back switched to settings again -- an inescapable
-- options menu. Every state's enter must lead with self, whether or not it uses it.
function settings.enter(self, previous)
    settings.previous = previous
    widget = SettingsMenu.build(backToPrevious, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = LIST_TOP,
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
    love.graphics.printf("Settings", 0, 100, Scale.WIDTH, "center")

    widget:draw()

    -- What the highlighted option actually buys, in the column the rows occupy so the prose lines up
    -- with what it describes. Only the selected row's line shows -- printing all of them would turn a
    -- short list of switches into a wall of prose.
    local item = widget:selectedItem()
    if item and item.description then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.ink)
        love.graphics.printf(item.description, Scale.WIDTH / 2 - ROW_W / 2, DESC_Y, ROW_W, "left")
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

function settings.keypressed(key)
    if key == "escape" then return backToPrevious() end
    widget:keypressed(key)
end

function settings.gamepadpressed(joystick, button)
    if button == "b" then return backToPrevious() end
    widget:gamepadpressed(joystick, button)
end

return settings
