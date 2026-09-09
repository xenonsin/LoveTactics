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
    {
        -- A fight is fought on the floor it was found on: states/game.lua stays the state and the board
        -- draws on top of it (battle.hosted). Every other input handler there hands the fight its input
        -- first; the cursor has to do the same, or every quest fight and every prologue stop shows one
        -- arrow whatever it is aimed at -- foe, walkable tile, combat panel and all. Read off the source
        -- for the reason the main.lua case above is: states/game.lua builds fonts at require time and
        -- cannot be loaded without a window.
        name = "the overworld hands a hosted fight the cursor, as it hands it every other input",
        fn = function()
            local src = assert(love.filesystem.read("states/game.lua"), "states/game.lua is readable")
            local body = src:match("function game:cursorKind%(.-\n(.-)\nend\n")
            assert(body, "states/game.lua no longer defines game:cursorKind")
            assert(body:find("battling%(%)") and body:find("game%.battle%.cursorKind"),
                "the overworld answers for the cursor while a fight is hosted on it -- the whole "
                .. "board, foes and panel included, will read as one arrow")
        end,
    },
    {
        -- A `target = "tile"` weapon -- a spear's line, an axe's arc -- arrives under the same `place`
        -- kind a trap laid or a sentry emplaced does, because a footprint is authored around a square.
        -- Handing all of them the placement reticle put one glyph over every tile a whole weapon family
        -- could reach, foe and empty dirt alike, so the cursor said the same thing everywhere. What the
        -- swing CATCHES is what decides it. Read off the source for the reason the drag guards are
        -- (tests/battle_drag_spec.lua): the reading wants a whole rolled fight standing behind it.
        name = "a tile-aimed swing that catches a body reads as a blow, not as a placement",
        fn = function()
            local src = assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
            local body = src:match("function battle%.boardCursorKind%(%)\n(.-)\nend\n")
            assert(body, "states/battle.lua no longer defines battle.boardCursorKind")
            assert(body:find("a%.order"),
                "the tile-aimed branch no longer asks the dry run which bodies the cast would touch")
            assert(body:find("a%.actor"),
                "the tile-aimed branch counts the caster among the bodies it caught, so a ward "
                .. "centred on the caster reads as a blow")
            assert(body:find('kind%s*=%s*"ability"'),
                "nothing promotes a tile-aimed cast that lands on a foe to a blow -- a spear and an "
                .. "axe wear the placement reticle over every square they can reach")
        end,
    },
}
