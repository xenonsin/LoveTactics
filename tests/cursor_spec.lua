-- Tests for the context cursor's kind table (ui/cursor.lua). The glyphs are pure love.graphics
-- drawing that needs a live GL context, which the headless runner has NOT got (conf.lua disables
-- the window) -- issuing a real draw call there hard-crashes the process, so these tests stay at
-- the data layer: the kind->glyph mapping is complete and lookups behave, which is what the states
-- actually depend on. The drawing itself is covered by the in-game verification pass.

local Cursor = require("ui.cursor")

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
}
