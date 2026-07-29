-- Builds the preferences list as a ui/menu.lua widget: one row per option in models/settings.lua,
-- plus a Back row. Extracted from states/settings.lua so the SAME list can be shown two ways -- as the
-- full-screen settings state, and as a modal overlay inside a battle (states/battle.lua) -- without
-- either copying the row logic. One source of truth for what a preference row does.
--
--   local widget = SettingsMenu.build(onBack, { font = ..., startY = ... })
--
-- `onBack` runs when the Back row is chosen (Esc/B are the caller's to wire). `opts` are forwarded to
-- Menu.new (buttonWidth/Height, spacing, startY, centerX, font).
--
-- Range rows (the volumes) carry two extra hooks the menu widget uses to render them as a SLIDER:
--   sliderFraction() -> 0..1   the fill to draw
--   sliderSet(frac)            set the level from a click position, snapped to the option's step
-- so a mouse can lower a volume by clicking, not only nudge it up via the row's action. Left/right
-- (keyboard, d-pad) still step it through `adjust`, unchanged.

local Menu = require("ui.menu")
local Settings = require("models.settings")
local Sound = require("models.sound")
local Theme = require("ui.theme")

local SettingsMenu = {}

local ON, OFF = "On", "Off"

-- A range row's readout. Zero reads as "Off" rather than "0%": at zero a volume is not a quiet
-- setting, it is a disabled one, and the word says so at a glance down the column.
local function rangeLabel(value, def)
    if value == nil then value = def.default end
    if value <= (def.min or 0) then return OFF end
    return value .. "%"
end

function SettingsMenu.build(onBack, opts)
    opts = opts or {}
    local items = {}
    for _, def in ipairs(Settings.defs) do
        local row = {
            label = def.name,
            description = def.description,
            -- Read live, so the row shows what the preference IS rather than what it was when this
            -- widget was built -- which is also what lets one `adjust` serve the click, Enter and the
            -- d-pad without any of them having to refresh the label.
            value = function()
                local value = Settings.get(def.key)
                if def.kind == "range" then return rangeLabel(value, def) end
                return value and ON or OFF
            end,
        }

        if def.kind == "range" then
            local lo, hi = def.min or 0, def.max or 100
            local span = hi - lo

            -- Persist, then make the change audible: push the new level onto whatever is already
            -- playing (a volume you cannot hear until the next track is not a control), and blip the
            -- effects channel so IT has something to be heard on -- but not the music channel, where a
            -- blip is the wrong sound for the thing changing.
            local function apply()
                Settings.save()
                Sound.refresh()
                if def.key ~= "volume_music" then Sound.play("ui.move") end
            end

            -- `adjust` is ui/menu.lua's hook for a row with more than two states: left and right step
            -- it, and Enter (which falls through to `action`) nudges it up so a keypress still does
            -- something.
            row.adjust = function(dir)
                Settings.step(def.key, dir)
                apply()
            end
            row.action = function() row.adjust(1) end

            -- Slider hooks: the fill the widget draws, and the setter a mouse click drives by position.
            row.sliderFraction = function()
                if span <= 0 then return 0 end
                return ((Settings.get(def.key) or def.default) - lo) / span
            end
            row.sliderSet = function(frac)
                frac = math.max(0, math.min(1, frac or 0))
                local step = def.step or 1
                -- Snap the clicked position to the nearest step, so the slider lands on the same values
                -- the arrow keys reach and the readout is always a clean multiple.
                local snapped = lo + math.floor(frac * span / step + 0.5) * step
                if snapped < lo then snapped = lo end
                if snapped > hi then snapped = hi end
                Settings.set(def.key, snapped)
                apply()
            end
        else
            row.action = function()
                Settings.toggle(def.key)
                Settings.save()
            end
        end

        items[#items + 1] = row
    end
    items[#items + 1] = { label = "Back", action = onBack }

    return Menu.new(items, {
        buttonWidth = opts.buttonWidth or 620,
        buttonHeight = opts.buttonHeight or 46,
        spacing = opts.spacing or 10,
        startY = opts.startY,
        centerX = opts.centerX,
        font = opts.font or Theme.display(20),
    })
end

return SettingsMenu
