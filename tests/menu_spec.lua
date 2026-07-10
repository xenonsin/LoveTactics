-- Tests for the ui/menu.lua scroll window. `Menu.new` builds a font, which needs a graphics
-- device, so these build instances straight through the metatable -- the scroll logic itself
-- is pure arithmetic over `items`, `selected`, and `scroll`.

local Menu = require("ui.menu")

-- A menu of `n` rows showing `maxVisible` at a time (nil = show everything).
local function menu(n, maxVisible)
    local items = {}
    for i = 1, n do items[i] = { label = "row " .. i } end
    return setmetatable({
        items = items,
        selected = 1,
        scroll = 0,
        maxVisible = maxVisible,
        buttonWidth = 100, buttonHeight = 10, spacing = 0,
        startY = 0, centerX = 100,
    }, Menu)
end

-- The 1-based indices currently inside the scroll window.
local function visibleIndices(m)
    local out = {}
    for i = 1, #m.items do
        if m:isVisible(i) then out[#out + 1] = i end
    end
    return out
end

return {
    {
        name = "a menu shorter than its window does not scroll",
        fn = function()
            local m = menu(3, 6)
            assert(not m:canScroll(), "3 rows in a 6-row window cannot scroll")
            assert(m:visibleCount() == 3, "all three rows are visible")

            m:moveSelection(1)
            assert(m.scroll == 0, "the window never moves")
        end,
    },
    {
        name = "a menu with no maxVisible shows every row",
        fn = function()
            local m = menu(50)
            assert(not m:canScroll(), "an uncapped menu never scrolls")
            assert(m:visibleCount() == 50, "every row is visible")
            assert(#visibleIndices(m) == 50, "every row lays out")
        end,
    },
    {
        name = "moving the selection past the bottom drags the window down one row at a time",
        fn = function()
            local m = menu(9, 6)
            assert(m:canScroll(), "9 rows in a 6-row window scrolls")

            for _ = 1, 5 do m:moveSelection(1) end
            assert(m.selected == 6, "selection should reach the last visible row")
            assert(m.scroll == 0, "the window has not needed to move yet")

            m:moveSelection(1)
            assert(m.selected == 7 and m.scroll == 1, "row 7 pulls the window down by one")

            local visible = visibleIndices(m)
            assert(visible[1] == 2 and visible[#visible] == 7, "rows 2..7 are on screen")
        end,
    },
    {
        name = "wrapping from the last row back to the first snaps the window home",
        fn = function()
            local m = menu(9, 6)
            m.selected, m.scroll = 9, 3

            m:moveSelection(1) -- wraps to row 1
            assert(m.selected == 1, "selection wraps to the top")
            assert(m.scroll == 0, "the window follows it home")
            assert(m:isVisible(1), "the selected row is on screen")
        end,
    },
    {
        name = "wrapping backwards from the first row scrolls to the bottom of the list",
        fn = function()
            local m = menu(9, 6)

            m:moveSelection(-1) -- wraps to row 9
            assert(m.selected == 9, "selection wraps to the bottom")
            assert(m.scroll == 3, "the window shows the last six rows")
            assert(m:isVisible(9), "the selected row is on screen")
        end,
    },
    {
        name = "the selected row is always inside the window, however it is reached",
        fn = function()
            local m = menu(11, 4)
            for _ = 1, 30 do
                m:moveSelection(1)
                assert(m:isVisible(m.selected), "selection left the window going down")
            end
            for _ = 1, 30 do
                m:moveSelection(-1)
                assert(m:isVisible(m.selected), "selection left the window going up")
            end
        end,
    },
    {
        name = "the wheel scrolls the window without moving the selection, and clamps at both ends",
        fn = function()
            local m = menu(9, 6)

            m:wheelmoved(0, -1) -- wheel down
            assert(m.scroll == 1, "the window moved down one row")
            assert(m.selected == 1, "the selection did not move")

            m:wheelmoved(0, -50)
            assert(m.scroll == 3, "scrolling past the end clamps at the last full window")

            m:wheelmoved(0, 50)
            assert(m.scroll == 0, "scrolling past the start clamps at the top")
        end,
    },
    {
        name = "the wheel does nothing on a list that fits",
        fn = function()
            local m = menu(3, 6)
            m:wheelmoved(0, -5)
            assert(m.scroll == 0, "a list that fits never scrolls")
        end,
    },
    {
        name = "page keys jump a windowful and keep the selection on screen",
        fn = function()
            local m = menu(20, 5)
            m:keypressed("pagedown")
            assert(m.selected == 6, "pagedown advances by one window")
            assert(m:isVisible(6), "the selection stays on screen")

            m:keypressed("pageup")
            assert(m.selected == 1, "pageup returns")
            assert(m.scroll == 0, "and the window with it")
        end,
    },
    {
        name = "rows outside the window get no rect, so they cannot be clicked",
        fn = function()
            local m = menu(9, 6)
            m:layout()

            assert(m.items[6].x, "row 6 is on screen and has a rect")
            assert(m.items[7].x == nil, "row 7 is scrolled out and has none")

            -- A click at the seventh row's would-be position hits nothing.
            m:mousemoved(100, 6 * 10 + 5)
            assert(m.selected == 1, "hovering past the window changes nothing")
        end,
    },
    {
        name = "moveSelection on an empty menu is a no-op rather than a divide by zero",
        fn = function()
            local m = menu(0, 6)
            m:moveSelection(1)
            assert(m.selected == 1, "an empty menu keeps a sane selection")
        end,
    },
}
