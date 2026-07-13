-- Tracks which device the player last used -- "keyboard", "mouse", or "gamepad" -- so on-screen
-- prompts can show the matching glyphs (pad buttons vs. keyboard keys) and mouse-driven screens can
-- suppress the keyboard/pad cursor tooltip. Updated from the global input forwarders in main.lua
-- (a key press, a mouse move/click/wheel, a pad button, or a past-deadzone stick/trigger axis), so
-- every state and widget reads one shared source of truth.
--
--   local InputMode = require("input_mode")
--   if InputMode.isGamepad() then ... end

local InputMode = { current = "keyboard" }

-- Ignore analog drift: only a real deflection past this counts as "using the gamepad".
InputMode.AXIS_DEADZONE = 0.5

function InputMode.set(mode)
    InputMode.current = mode
end

-- Set gamepad mode only when an axis actually moves past the deadzone (stick drift stays quiet).
function InputMode.axis(value)
    if math.abs(value) >= InputMode.AXIS_DEADZONE then
        InputMode.current = "gamepad"
    end
end

function InputMode.isKeyboard() return InputMode.current == "keyboard" end
function InputMode.isMouse() return InputMode.current == "mouse" end
function InputMode.isGamepad() return InputMode.current == "gamepad" end

return InputMode
