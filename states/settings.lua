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
local Menu = require("ui.menu")
local Settings = require("models.settings")
local Sound = require("models.sound")
local Scale = require("scale")
local InputMode = require("input_mode")

local settings = {}

local titleFont = love.graphics.newFont(40)
local bodyFont = love.graphics.newFont(16)
local rowFont = love.graphics.newFont(20)

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

local ON, OFF = "On", "Off"

local function backToPrevious()
    State.switch(settings.previous or require("states.menu"))
end

-- A range row's readout. Zero reads as "Off" rather than "0%": at zero a volume is not a quiet
-- setting, it is a disabled one, and the word says so at a glance down the column.
local function rangeLabel(value, def)
    if value == nil then value = def.default end
    if value <= (def.min or 0) then return OFF end
    return value .. "%"
end

local function buildMenu()
    local items = {}
    for _, def in ipairs(Settings.defs) do
        local row = {
            label = def.name,
            description = def.description,
            -- Read live, so the row shows what the preference IS rather than what it was when this
            -- screen opened -- which is also what lets one `action` serve the click, Enter and the
            -- d-pad without any of them having to refresh the label.
            value = function()
                local value = Settings.get(def.key)
                if def.kind == "range" then return rangeLabel(value, def) end
                return value and ON or OFF
            end,
        }

        if def.kind == "range" then
            -- `adjust` is ui/menu.lua's hook for a row with more than two states: left and right step
            -- it, and Enter (which falls through to `action`) nudges it up so a click still does
            -- something rather than nothing.
            row.adjust = function(dir)
                Settings.step(def.key, dir)
                Settings.save()
                -- Push the new level onto whatever is already playing, so the slider is audible while
                -- you move it. A volume control you cannot hear until the next track is not a control.
                Sound.refresh()
                -- ... and give the effects slider something to be heard ON. Only for sfx: firing a
                -- blip every step of the MUSIC slider would be the wrong sound for the thing changing.
                if def.key ~= "volume_music" then Sound.play("ui.move") end
            end
            row.action = function() row.adjust(1) end
        else
            row.action = function()
                Settings.toggle(def.key)
                Settings.save()
            end
        end

        items[#items + 1] = row
    end
    items[#items + 1] = { label = "Back", action = backToPrevious }
    return Menu.new(items, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        startY = LIST_TOP,
        font = rowFont,
    })
end

-- Note the `self` first parameter. State.switch calls `state.enter(state, ...)`, so the state's own
-- table always arrives ahead of the caller's arguments (states/init.lua). Written as `enter(previous)`
-- this screen took ITSELF as the previous state and Back switched to settings again -- an inescapable
-- options menu. Every state's enter must lead with self, whether or not it uses it.
function settings.enter(self, previous)
    settings.previous = previous
    widget = buildMenu()
end

function settings.update(dt)
    widget:update(dt)
end

function settings.draw()
    -- Fill the logical area explicitly: letterbox bars are cleared to black, so setBackgroundColor
    -- (which paints the whole real window) can't be used here. Mirrors states/menu.lua.
    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Settings", 0, 100, Scale.WIDTH, "center")

    widget:draw()

    -- What the highlighted option actually buys, in the column the rows occupy so the prose lines up
    -- with what it describes. Only the selected row's line shows -- printing all of them would turn a
    -- short list of switches into a wall of prose.
    local item = widget:selectedItem()
    if item and item.description then
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(0.62, 0.66, 0.76)
        love.graphics.printf(item.description, Scale.WIDTH / 2 - ROW_W / 2, DESC_Y, ROW_W, "left")
    end

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.45, 0.50, 0.62)
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
