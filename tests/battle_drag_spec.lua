-- Dragging the acting character to a tile to spend its turn there (states/battle.lua).
--
-- Tap-to-aim and tap-again-to-commit asks for two presses and hides the destination under the thumb
-- for the whole of the second one. Picking the body up and dropping it where it should go says actor
-- and destination in one motion, and the preview that follows the finger is the rehearsal a mouse
-- gets from its hover. One gesture covers both verbs because the board already resolves both from a
-- single aimed cell: drop on open ground and the unit walks, drop on a foe and the armed item swings.
--
-- Read off the source, as the tap-twice guard beside it is (tests/touch_prompt_spec.lua): a live
-- battle.mousereleased wants a whole rolled fight behind it, and this file is the only thing standing
-- between these four guards and a silent removal.

local function battleSource()
    return assert(love.filesystem.read("states/battle.lua"), "states/battle.lua is readable")
end

return {
    {
        -- Whose body, and only whose. Every other unit on the board keeps the long press that reads
        -- its card, and a drag begun on empty ground is not an intent to move anybody.
        name = "only the acting character can be picked up, and only by a finger",
        fn = function()
            local body = assert(battleSource():match("function battle%.dragTarget(.-)\nend"),
                "battle.dragTarget is gone or renamed")
            assert(body:find("InputMode%.touch"),
                "the drag arms for every device, so a mouse now waits for a release to act")
            assert(body:find("Combat%.unitAt%(battle%.combat, cx, cy%) ~= current"),
                "the press does not check it landed on the acting unit -- any tile now starts a drag")
            assert(body:find("Combat%.isPlayerControlled"),
                "an enemy's turn can be dragged through")
            assert(body:find("busy%(%)"),
                "a body can be dragged mid-walk or mid-animation, on top of the action already running")
            -- The two surfaces that float OVER the board. cellAt answers for a point beneath them, so
            -- without these a press on the panel or the open log picks the character up as well.
            assert(body:find("battle%.log:contains") and body:find("battle%.panel:contains"),
                "a press on the log or the combat panel starts a board drag underneath it")
        end,
    },
    {
        -- The fork between the two gestures that share this press. Both are resolved on the release,
        -- and what tells them apart is whether the finger moved.
        name = "a finger that slides is dragging, and the cursor follows it",
        fn = function()
            local src = battleSource()
            local moved = assert(src:match("function battle%.mousemoved(.-)\nend"),
                "battle.mousemoved is gone or renamed")
            assert(moved:find("battle%.drag%.live"), "nothing promotes the press to a drag")
            assert(moved:find("battle%.map:mousemoved"),
                "the board cursor does not follow the finger, so the drag has no preview and the drop"
                .. " lands wherever the last hover left the cursor")
            -- The early return is load-bearing: further down, mousemoved hands the point to the panel
            -- and returns if it is over it, which would strand the cursor mid-drag.
            assert(moved:find("battle%.map:mousemoved%(x, y%) return end"),
                "the drag does not claim the move, so dragging across the panel leaves the cursor behind")
            assert(moved:find("battle%.aim = nil"),
                "the tap-tap aim survives the drag, so a drop can confirm a tile the player aimed at"
                .. " with an earlier tap rather than the one under their finger")
        end,
    },
    {
        name = "the drop commits through the same seam every other input confirms through",
        fn = function()
            local body = assert(battleSource():match("function battle%.mousereleased(.-)\nend"),
                "battle.mousereleased is gone or renamed")
            local drop = assert(body:match("if battle%.drag and button == 1 then(.-)\n    end"),
                "the drop is gone: a drag can be started and never resolved")
            assert(drop:find("battle%.map:mousepressed%(x, y, 1%)"),
                "the drop does not aim the cell it was released over")
            assert(drop:find("confirm%(%)"),
                "the drop aims but never acts -- the drag ends by putting the character back")
            -- cellAt (through map:mousepressed's return) is the off-board cancel: a drag carried out
            -- of the arena must not spend the turn on the last tile it crossed on the way.
            assert(drop:find("if battle%.map:mousepressed%(x, y, 1%)%s*\r?\n?%s*and"),
                "the commit is not gated on the release landing on a cell, so letting go off the board"
                .. " still spends the turn")
            assert(drop:find("d%.unit == battle%.current") and drop:find("d%.item == battle%.armedItem"),
                "the drag does not carry its actor and armed item, so a drop can commit an intent"
                .. " formed against a different unit or a different weapon")
        end,
    },
    {
        -- A drag that never passed the slop is a tap, and the tap path is the one that already works.
        -- If this stops falling through, tapping the acting character stops aiming at all.
        name = "a drag that never moved is still a tap",
        fn = function()
            local body = assert(battleSource():match("function battle%.mousereleased(.-)\nend"),
                "battle.mousereleased is gone or renamed")
            local drop = assert(body:match("if battle%.drag and button == 1 then(.-)\n    end"), "no drop")
            assert(drop:find("if d%.live then"),
                "every release is treated as a drop, so a plain tap on your own unit no longer aims")
            local pressAt = assert(body:find("if battle%.hold and button == 1 then"),
                "the hold's tap replay is gone")
            assert(body:find("if battle%.drag and button == 1 then") < pressAt,
                "the hold replay is asked first, so a matured drag is replayed as a tap as well")
        end,
    },
}
