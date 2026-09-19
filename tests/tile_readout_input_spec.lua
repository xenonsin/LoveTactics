-- WHO CAN ASK A TILE WHAT IT IS (states/battle.lua's docked left column).
--
-- The column holds the ground, whoever is standing on it, and the forecast for the blow being lined
-- up at them -- the one readout the whole fight is aimed through. It was built for a pointer and read
-- only from one: `battle.drawTileTooltip(mx, my)` took the MOUSE POSITION and turned it into a cell.
-- A keyboard or a pad steers a board cursor and never moves that pointer, so the column stayed empty
-- for the whole fight; a finger had it switched off outright, because the version it had followed the
-- last touched POSITION -- which outlives the intent that set it and kept describing whatever the
-- finger last brushed on its way to a button.
--
-- Both now name the cell directly (battle.drawTileTooltipAt), which is what the deployment phase
-- before the bell already did with its own cursor (ui/deploy_phase.lua's hoverCell). The project
-- standard is mouse + keyboard + gamepad on every surface, and this is the surface where an aim is
-- read -- so a device that cannot raise it cannot see what it is about to attack.
--
-- Read off the source, as tests/battle_drag_spec.lua and tests/touch_prompt_spec.lua are: a live
-- battle.draw wants a rolled fight, a window and a font behind it, and this file is the only thing
-- standing between these guards and a silent removal.

local function battleSource()
    return assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
end

-- The tooltip chain in battle.draw: one if/elseif ladder, from the pinned reading down to the mouse's
-- hover. Everything inside it is indented past four spaces, so the first `\n    end` is its closer.
-- Anchored on the pointer read directly above it, since `if battle.inspect then` opens a second,
-- unrelated block further down the file (battle.mousepressed dismisses a pinned reading with one).
local function tooltipChain(src)
    return assert(src:match("battle%.mouseX, battle%.mouseY\n.-\n    if battle%.inspect then(.-)\n    end"),
        "the tooltip chain in battle.draw is gone or has been re-shaped")
end

-- Comments out. Every branch below is argued for at length in prose that NAMES the thing it was
-- written to rule out ("not off battle.mouseX"), so a spec reading the raw text finds the forbidden
-- field in the very sentence forbidding it.
local function code(text)
    return (text:gsub("%-%-[^\n]*", ""))
end

return {
    {
        -- The seam itself. One body, addressed two ways: the pointer path converts and forwards, so a
        -- section added to the readout cannot reach a mouse and miss the other two devices.
        name = "the tile readout is addressable by cell, and the pointer path forwards to it",
        fn = function()
            local src = battleSource()
            assert(src:find("function battle%.drawTileTooltipAt%(cx, cy%)"),
                "battle.drawTileTooltipAt is gone -- a pointerless device has no way to name a tile")
            local byPointer = assert(src:match("function battle%.drawTileTooltip%(mx, my%)(.-)\nend"),
                "battle.drawTileTooltip is gone or renamed")
            assert(byPointer:find("battle%.drawTileTooltipAt%(cx, cy%)"),
                "the mouse keeps its own copy of the readout body, so the two surfaces will drift")
        end,
    },
    {
        -- Keyboard and pad. The cursor IS the hover on those devices; nothing else on screen can
        -- stand in for it.
        name = "a keyboard or pad reads the tile its board cursor rests on",
        fn = function()
            local chain = tooltipChain(battleSource())
            local branch = code(assert(chain:match("elseif not InputMode%.isMouse%(%) then(.-)elseif"),
                "the keyboard/pad branch of the tooltip chain is gone -- the docked column is"
                .. " mouse-only again"))
            assert(branch:find("battle%.map%.cursor"),
                "the branch does not read the board cursor, so a steered aim describes nothing")
            assert(branch:find("battle%.drawTileTooltipAt"),
                "the branch raises no tile readout -- terrain, occupant and forecast are mouse-only")
        end,
    },
    {
        -- ...and the selected slot's own tooltip alongside it, not instead of it. A pointer has one
        -- position and must choose between the tile and the ability; a keyboard holds both at once,
        -- and they are answered in opposite columns.
        name = "a selected ability slot does not cost the keyboard its tile readout",
        fn = function()
            local chain = tooltipChain(battleSource())
            assert(not chain:find("elseif not InputMode%.isMouse%(%) and battle%.keySlot then"),
                "the selected slot is an exclusive branch again, so picking an ability blanks the"
                .. " column that says what it would hit")
            local branch = code(assert(chain:match("elseif not InputMode%.isMouse%(%) then(.-)elseif"),
                "the keyboard/pad branch of the tooltip chain is gone"))
            assert(branch:find("battle%.keySlot") and branch:find("ItemTooltip%.draw"),
                "the selected slot lost its own tooltip, so a numpad press no longer reads the item")
        end,
    },
    {
        -- Touch. The aim is the finger's hover, and it is read off the commit latch rather than off a
        -- pinned position: an aim carries the actor it was formed under and goes stale with it, so the
        -- boxes stand exactly as long as the intent they describe.
        name = "a finger reads the tile its tap is standing on, and only while that aim stands",
        fn = function()
            local chain = tooltipChain(battleSource())
            local branch = code(assert(chain:match("elseif InputMode%.touch then(.-)elseif"),
                "the touch branch of the tooltip chain is gone"))
            assert(branch:find("battle%.aim"),
                "the finger's branch does not read the aim, so a tap answers nothing")
            assert(branch:find("battle%.drawTileTooltipAt"),
                "a tap raises no tile readout -- a finger is back to no answer at all")
            assert(not branch:find("battle%.mouseX"),
                "the column follows the last touched POSITION again, which outlives the aim that set"
                .. " it and describes whatever the finger last brushed")
            assert(branch:find("battle%.current"),
                "the aim is read without its staleness guard, so a tile aimed at two turns ago is"
                .. " still being described")
        end,
    },
}
