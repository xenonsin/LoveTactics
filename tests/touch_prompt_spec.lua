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
        name = "the docked inspector follows a finger, which has no hover to follow",
        fn = function()
            local src = assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
            assert(src:find("if InputMode%.touch then battle%.mouseX, battle%.mouseY = x, y end"),
                "nothing pins the hover position on a tap, so the whole left column stays blank on a "
                .. "handset for the entire fight")
        end,
    },
    {
        -- The rotate ask, and the two ways it can silently stop working: shown to a desktop
        -- window dragged tall, or shown over the download gate instead of the game.
        name = "a portrait handset is asked to turn, and only a handset is",
        fn = function()
            local src = assert(love.filesystem.read("tools/web/index.html"), "the web shell is readable")
            assert(src:find("id=\"rotate\"", 1, true), "there is no rotate prompt")
            assert(src:find("pointer: coarse", 1, true) and src:find("orientation: portrait", 1, true),
                "the prompt is not gated on BOTH a finger and a portrait screen -- a desktop window"
                .. " dragged tall would be told to turn a monitor")
            assert(src:find("rotate%-dismiss"), "no way past it: someone playing upright on purpose"
                .. " (orientation lock, lying down) would be stuck behind it")
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
