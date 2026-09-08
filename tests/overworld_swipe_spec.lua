-- Swiping the floor to take a step (ui/overworld_map.lua).
--
-- A mouse points at a destination and the party walks to it. That is a good gesture for a pointer and
-- a poor one for a thumb, which is nowhere near the tile it wants and covers it on arrival. A swipe
-- names a DIRECTION instead -- the same thing the keyboard and the d-pad have always said here -- so
-- it feeds the same single step rather than becoming a second way to move.
--
-- Exercised on a bare stub rather than a rolled map: every branch under test returns before it
-- touches the grid, and a real map would drag a whole floor in to assert four numbers.

local OverworldMap = require("ui.overworld_map")

local function released(press, x, y, extra)
    local m = { press = press, autoPath = "a walk in progress" }
    for k, v in pairs(extra or {}) do m[k] = v end
    OverworldMap.mousereleased(m, x, y, 1)
    return m
end

return {
    {
        name = "a swipe becomes exactly one step, in one cardinal direction",
        fn = function()
            local right = released({ x = 100, y = 100 }, 160, 104)
            assert(right.swipe and right.swipe[1] == 1 and right.swipe[2] == 0,
                "a swipe right did not step right")
            local up = released({ x = 100, y = 100 }, 103, 40)
            assert(up.swipe and up.swipe[1] == 0 and up.swipe[2] == -1, "a swipe up did not step up")
            -- No diagonals: the grid has four neighbours, so a clearly dominant axis takes the whole
            -- step. (100 across against 40 down -- a drag that IS mostly sideways. A 60/45 drag is
            -- rejected as a smudge instead, which is the case below.)
            local diag = released({ x = 100, y = 100 }, 200, 140)
            assert(diag.swipe and diag.swipe[1] == 1 and diag.swipe[2] == 0,
                "a lopsided drag produced a diagonal the grid cannot walk")
        end,
    },
    {
        -- The two ways this quietly stops being a gesture: too short (a shaky tap becomes a step) or
        -- too square (a smudge picks an axis at random).
        name = "a short or shapeless drag is a tap, not a swipe",
        fn = function()
            local short = released({ x = 100, y = 100 }, 120, 104, { walkToPixel = function() end })
            assert(not short.swipe, "20px of wobble was read as a deliberate swipe")
            local square = released({ x = 100, y = 100 }, 150, 148, { walkToPixel = function() end })
            assert(not square.swipe,
                "a diagonal smudge with no dominant axis picked one anyway")
        end,
    },
    {
        name = "a swipe interrupts the walk it lands during, and is consumed once",
        fn = function()
            local m = released({ x = 100, y = 100 }, 160, 104)
            assert(m.autoPath == nil,
                "a swipe left the queued walk running, so the party keeps going where it was sent")
            local dx, dy = OverworldMap.heldDirection(m)
            assert(dx == 1 and dy == 0, "heldDirection did not report the swipe")
            assert(m.swipe == nil, "the swipe was not consumed -- the party walks on forever")
        end,
    },
    {
        -- A mouse must keep pathing on the PRESS: no drag, no wait for a release. Read off the source
        -- because the press path wants a real grid to walk on.
        name = "a mouse still paths on the press, and only a finger defers",
        fn = function()
            local src = assert(love.filesystem.read("ui/overworld_map.lua"), "the map is readable")
            local press = src:match("function OverworldMap:mousepressed(.-)\nend")
            assert(press, "mousepressed is gone or renamed")
            assert(press:find("InputMode%.touch"),
                "the press defers for every device, so a mouse now waits for a release to walk")
            assert(press:find("walkToPixel"), "a mouse press no longer walks anywhere")
        end,
    },
}
