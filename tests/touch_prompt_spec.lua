-- Control prompts naming the device actually in the player's hands, and the one control that had no
-- touch route at all.
--
-- Every prompt in the game was written with two branches -- gamepad, or "click / press Esc" -- and a
-- handset is mouse mode by design (see input_mode.lua), so it fell into the second and was told to
-- click. Worse than wrong wording: Dialogue's skip is `escape` or `B` and nothing else, so a phone
-- player could not leave a scene at all while the footer said Esc.

local InputMode = require("input_mode")

-- InputMode is a singleton the whole suite shares; put back whatever we borrowed.
local function withMode(mode, touch, fn)
    local m, t = InputMode.current, InputMode.touch
    InputMode.current, InputMode.touch = mode, touch
    local ok, err = pcall(fn)
    InputMode.current, InputMode.touch = m, t
    assert(ok, err)
end

return {
    {
        name = "pick answers with the device in hand, and touch is not the keyboard branch",
        fn = function()
            withMode("gamepad", false, function()
                assert(InputMode.pick("pad", "tap", "key") == "pad", "a pad must get the pad wording")
            end)
            withMode("mouse", true, function()
                assert(InputMode.pick("pad", "tap", "key") == "tap",
                    "a finger fell through to the keyboard wording -- the whole bug")
            end)
            withMode("mouse", false, function()
                assert(InputMode.pick("pad", "tap", "key") == "key", "a mouse must get the key wording")
            end)
            withMode("keyboard", false, function()
                assert(InputMode.pick("pad", "tap", "key") == "key", "a keyboard must get the key wording")
            end)
        end,
    },
    {
        -- The nil case is the point of the three-way split: some controls genuinely have no finger
        -- route, and the caller must be able to draw NOTHING rather than name a missing key.
        name = "a control with no touch route reports nothing rather than naming a key",
        fn = function()
            withMode("mouse", true, function()
                assert(InputMode.pick("B", nil, "Esc") == nil,
                    "touch must be able to say 'there is no route', not fall back to Esc")
            end)
        end,
    },
    {
        -- Reachability, not wording. love.draw cannot run headlessly, so the route is read off the
        -- source -- the same check the quarter turn and the drawn cursor needed, for the same reason.
        name = "the dialogue offers a finger a way out of a scene",
        fn = function()
            local src = assert(love.filesystem.read("ui/dialogue.lua"), "ui/dialogue.lua is readable")
            assert(src:find("function Dialogue:skipRect"),
                "no skip control -- a touch player cannot leave a scene, and Esc is not on the device")
            assert(src:find("pointIn%(self:skipRect%(%)"),
                "the skip control is drawn but never hit-tested, so pressing it does nothing")
            assert(src:find("InputMode%.touch"),
                "skipRect must be gated on touch: the desktop row already names a key that works")
        end,
    },
    {
        -- The prompts that used to tell a phone to click. Named individually rather than by a blanket
        -- grep, because plenty of OTHER two-branch isGamepad() reads are correct -- focus rings and
        -- the like, where touch really does behave as the mouse does.
        name = "the panels that told a finger to click no longer do",
        fn = function()
            local files = {
                "ui/panels/advancement.lua", "ui/panels/battle_summary.lua",
                "ui/panels/placeholder.lua", "ui/panels/system_menu.lua",
                "ui/panels/tutorial_note.lua", "ui/dialogue.lua",
            }
            for _, path in ipairs(files) do
                local src = assert(love.filesystem.read(path), path .. " is readable")
                assert(src:find("InputMode%.pick%("),
                    path .. " still picks its control hint with two branches, so a handset is told to click")
            end
        end,
    },
    {
        -- A mouse click is rehearsed by the hover that preceded it; a tap is not. Read off the source
        -- because a real battle.mousepressed wants a whole live fight, and this file is the only thing
        -- standing between the guard and a silent removal.
        name = "the board asks a finger twice before it spends a turn",
        fn = function()
            local src = assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
            local tail = src:match("if battle%.map:mousepressed.*$")
            assert(tail, "the board's commit call is gone or renamed")
            assert(tail:find("InputMode%.touch"),
                "a tap still commits on the first press -- one fat finger costs the turn")
            assert(tail:find("battle%.aim"), "there is no aim to confirm against")
            -- The staleness guard is the half that is easy to drop and impossible to see fail.
            assert(tail:find("a%.unit == battle%.current") and tail:find("a%.item == battle%.armedItem"),
                "the aim does not carry its actor and armed item, so a tap two turns later can confirm "
                .. "an intent the player has forgotten forming")
        end,
    },
    {
        -- The authored coaching lines carry a {select} token so they can name whatever device is in
        -- hand. Touch fell into the mouse branch and the tutorial told a phone to click on a grunt.
        name = "a coaching line tells a finger to tap, not to click",
        fn = function()
            local Locale = require("models.locale")
            withMode("mouse", true, function()
                assert(Locale.selectWord() == "Tap", "a finger is told to click")
                assert(Locale.substitute("{select} on the grunt to jolt it.")
                    == "Tap on the grunt to jolt it.", "the token did not resolve for touch")
            end)
            withMode("mouse", false, function()
                assert(Locale.selectWord() == "Click", "a mouse must still be told to click")
            end)
            -- A pad and a keyboard have a real labelled button, so they keep the drawn cap and must
            -- not be dragged into the pointer branch by this.
            withMode("gamepad", false, function()
                assert(Locale.selectKey() == "A", "a pad lost its drawn cap")
            end)
            withMode("keyboard", false, function()
                assert(Locale.selectKey() == "Enter", "a keyboard lost its drawn cap")
            end)
        end,
    },
    {
        -- Reversed on 2026-09-07 after seeing it on a real handset: anchored to the tile, the
        -- forecast covers the board, which is the one thing you need in order to aim.
        name = "the forecast stays in the column and off the battlefield",
        fn = function()
            local src = assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
            local tail = src:match("Then the exchange.*$")
            assert(tail, "the exchange stack's draw block is gone or renamed")
            assert(not tail:find("cellBox"),
                "the forecast is anchored to a board tile again -- it will cover the battlefield")
        end,
    },
    {
        -- A tap on the board is free -- it aims, and a second tap commits -- so the board never needed
        -- a second gesture. A tap on an ITEM arms it, so there is no spare press to spend on reading
        -- one, and that is what the hold is for. Superseded the hover-driven docked column, which drew
        -- from the last tap and then stayed there over the turn order describing bare ground.
        name = "a long press pins a reading, and a press anywhere puts it away",
        fn = function()
            local src = assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
            assert(src:find("function battle%.holdTarget"),
                "nothing resolves what a long press would open")
            assert(src:find("battle%.hold%.elapsed >= 0%.4"),
                "the hold never matures -- there is no timer, or the threshold moved")
            assert(src:find("battle%.inspect, battle%.hold = nil, nil"),
                "a press does not dismiss the pinned reading")
            -- The press that dismisses must be SWALLOWED. Without the return it would also spend
            -- whatever it landed on, so putting a window away could cost a turn.
            -- Anchored on the assignment, not on `if battle.inspect then` -- the draw site opens with
            -- that same line and comes first in the file, so the loose pattern was checking the wrong
            -- block and passing on it.
            local dismiss = src:match("battle%.inspect, battle%.hold = nil, nil(.-)end")
            assert(dismiss and dismiss:find("return"),
                "the dismissing press falls through and acts on whatever was under the window")
            assert(src:find("battle%.holdReplaying"),
                "a press that did not become a hold is never replayed, so an ordinary tap does nothing")
            assert(src:find("elseif InputMode%.touch then"),
                "a finger still gets the hovered tooltip as well as the pinned one")
        end,
    },
    {
        -- A crash, on a phone, in shipped code: `local cx, cy = battle.map and battle.map:cellAt(x, y)`
        -- yields ONE value, because that is what an `and` expression is, so the row came back nil and
        -- Combat.unitAt compared it against a unit's. Only a finger ever ran the line -- dragTarget
        -- turns a mouse back before reaching it -- and it only errors when the press lands in a column
        -- somebody is standing in, which is how it got as far as a handset.
        --
        -- Guarded by shape rather than by call, because reaching the real dragTarget wants a live
        -- fight: what is asserted is that the two cell coordinates are not taken out of a truncating
        -- expression, and that a missing one turns the gesture down instead of travelling onward.
        name = "the drag reads a whole cell, not the first half of one",
        fn = function()
            local src = assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
            local fn = src:match("function battle%.dragTarget(.-)\nend")
            assert(fn, "battle.dragTarget is gone or renamed")
            assert(not fn:find("local %w+, %w+ = [%w_.]+ and "),
                "the cell pair is destructured out of an `and` expression again -- Lua yields one "
                    .. "value from that, so the row is nil and unitAt errors on the first body "
                    .. "sharing the pressed column")
            assert(fn:find("not cx or not cy"),
                "a half-resolved cell is passed on to unitAt instead of turning the drag down")
        end,
    },
    {
        -- The bubble that teaches, off the screen on a handset. Nothing in the placement search
        -- narrows the box: candidates that do not fit are rejected and the last resort clamps, but a
        -- clamp cannot rescue a box wider than the bounds -- it parks it at the left edge and the
        -- rest hangs off the far side. Raising the handheld width to 330 did exactly that in a board
        -- region 432 across. love.draw cannot run headlessly, so this is read off the source.
        name = "the coaching bubble is never wider than the room it was given",
        fn = function()
            local src = assert(love.filesystem.read("ui/coach_bubble.lua"), "the bubble is readable")
            local maxW = src:match("local maxW = ([^\n]*)")
            assert(maxW, "the bubble no longer decides a width before wrapping")
            assert(maxW:find("bounds%.w"),
                "the width is chosen without consulting the bounds, so a bubble too wide for its "
                    .. "region goes off screen instead of wrapping into it")
            -- The overworld's box was a file-scope constant stamped at require time, which is the
            -- wrong space the moment a handheld battle has changed the logical dimensions.
            local g = assert(love.filesystem.read("states/game.lua"), "the overworld is readable")
            assert(not g:find("local COACH_BOUNDS = {"),
                "the overworld's coach bounds are frozen at require time again -- they will be "
                    .. "measured against whatever space happened to be live when it was first loaded")
        end,
    },
    {
        -- The 3x3 item grid is a MECHANIC (Combat.adjacencyLinks: neighbouring cells form
        -- auras, boosts and requirements), so a slot cannot be widened by reshaping the grid
        -- to fit the actions a unit carries. The name band goes instead.
        name = "a handheld slot shows its icon, not an ellipsis",
        fn = function()
            local src = assert(love.filesystem.read("ui/combat_panel.lua"), "the panel is readable")
            assert(src:find("if not Scale%.inHandheldSpace then"),
                "the slot name band is drawn on a handheld again -- at 71px it can only ellipsize")
            local b = assert(love.filesystem.read("states/battle.lua"), "battle.lua is readable")
            assert(b:find("Scale%.inHandheldSpace and name and name ~= \"\""),
                "nothing names the armed item, so dropping the band loses the name entirely")
        end,
    },
}
