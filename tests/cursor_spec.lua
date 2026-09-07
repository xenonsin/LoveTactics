-- Tests for the context cursor's kind table (ui/cursor.lua). The glyphs are pure love.graphics
-- drawing that needs a live GL context, which the headless runner has NOT got (conf.lua disables
-- the window) -- issuing a real draw call there hard-crashes the process, so these tests stay at
-- the data layer: the kind->glyph mapping is complete and lookups behave, which is what the states
-- actually depend on. The drawing itself is covered by the in-game verification pass.

local Cursor = require("ui.cursor")
local InputMode = require("input_mode")

-- Every kind the states can return (battle.cursorKind + the menu/hub hand/arrow) must be mapped.
local EXPECTED = {
    "arrow", "hand", "move", "blink", "attack", "break", "cast", "heal", "target", "wait",
}

return {
    {
        name = "Cursor exposes a draw function and a KINDS table",
        fn = function()
            assert(type(Cursor.draw) == "function", "Cursor.draw missing")
            assert(type(Cursor.KINDS) == "table", "Cursor.KINDS missing")
        end,
    },
    {
        name = "every expected cursor kind is mapped to a glyph",
        fn = function()
            for _, kind in ipairs(EXPECTED) do
                assert(type(Cursor.KINDS[kind]) == "function",
                    "no glyph for kind '" .. kind .. "'")
            end
        end,
    },
    {
        name = "an unmapped kind has no glyph (draw falls back to the arrow)",
        fn = function()
            assert(Cursor.KINDS["no-such-kind"] == nil, "unexpected glyph for an unknown kind")
            assert(type(Cursor.KINDS.arrow) == "function", "arrow fallback glyph missing")
        end,
    },
    {
        -- A finger is a mouse for every purpose but one. The dozens of InputMode.isMouse() branches
        -- across the states must stay true under touch -- a tap presses what a click presses -- so
        -- the difference rides a separate flag rather than a fourth mode.
        name = "a touch pointer is still mouse mode, and is flagged as touch",
        fn = function()
            local mode, touch = InputMode.current, InputMode.touch
            InputMode.pointer(true)
            assert(InputMode.isMouse(), "a tap must leave the game in mouse mode")
            assert(InputMode.touch, "a tap must be flagged as touch")
            InputMode.pointer(false)
            assert(InputMode.isMouse(), "a real mouse is mouse mode")
            assert(not InputMode.touch, "a real mouse must clear the touch flag, so its cursor returns")
            InputMode.current, InputMode.touch = mode, touch
        end,
    },
    {
        -- The drawn cursor replaces a HIDDEN OS pointer, and a finger has no pointer to hide or to
        -- follow: left ungated the glyph appears on the first tap and sits there for the whole
        -- session. love.draw cannot run headlessly, so the gate is read off the source -- the same
        -- check the quarter turn needed (tests/letterbox_spec.lua) for the same reason.
        name = "main.lua draws no cursor for a finger, and arms touch mode on a handset",
        fn = function()
            local src = assert(love.filesystem.read("main.lua"), "main.lua is readable")
            assert(src:find("InputMode%.isMouse%(%)%s+and%s+not%s+InputMode%.touch"),
                "love.draw no longer excludes touch from the drawn cursor -- a tap will strand a "
                .. "glyph on the screen for the rest of the session")
            assert(src:find("InputMode%.touch%s*="),
                "main.lua never arms touch mode, so a handset shows the cursor until its first tap")
            assert(src:find("InputMode%.pointer%("),
                "the pointer callbacks no longer report which kind of pointer they came from")
        end,
    },
}
