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

-- A FINGER IS A MOUSE, with one exception. SDL delivers a tap as a mouse event, and every screen
-- in the game is right to treat it as one -- a tap presses what a click presses, and the dozens of
-- `InputMode.isMouse()` branches that suppress keyboard/pad focus rings want to be true on a
-- handset too. So touch stays inside "mouse" mode rather than becoming a fourth one.
--
-- The exception is HOVER, which a finger does not have. main.lua hides the OS pointer while the
-- mouse is live and draws ui/cursor.lua's glyph at it instead; with no pointer to follow, that
-- glyph strands itself wherever the last tap landed and sits there for the rest of the session.
-- This flag is what tells the two apart. It is set from the `istouch` every pointer callback
-- already carries, so a tablet with a mouse plugged in gets its cursor back on the first real
-- move, and cleared the same way.
InputMode.touch = false

function InputMode.set(mode)
    InputMode.current = mode
end

-- A pointer event, from either kind of pointer. `istouch` is the flag LOVE passes to mousemoved /
-- mousepressed / mousereleased.
function InputMode.pointer(istouch)
    InputMode.current = "mouse"
    InputMode.touch = istouch and true or false
end

-- Set gamepad mode only when an axis actually moves past the deadzone (stick drift stays quiet).
function InputMode.axis(value)
    if math.abs(value) >= InputMode.AXIS_DEADZONE then
        InputMode.current = "gamepad"
    end
end

-- Pick a control hint's wording for the device actually in the player's hands. Every prompt in the
-- game used to be written `InputMode.isGamepad() and "A to continue" or "Click to continue"`, which
-- has only two branches -- so a handset, which is mouse mode (see above), was told to click.
--
--   InputMode.pick("A to continue", "Tap to continue", "Enter / Click to continue")
--
-- `touchText` may be nil, meaning "a finger has no route to this at all" -- the caller then draws
-- nothing rather than naming a key that is not there. A prompt that advertises Esc to someone
-- holding a phone is worse than silence: it says the function exists and is reachable, and it is not.
function InputMode.pick(padText, touchText, keyText)
    if InputMode.isGamepad() then return padText end
    if InputMode.touch then return touchText end
    return keyText
end

function InputMode.isKeyboard() return InputMode.current == "keyboard" end
function InputMode.isMouse() return InputMode.current == "mouse" end
function InputMode.isGamepad() return InputMode.current == "gamepad" end

return InputMode
