-- The hub's burger button (ui/burger_button.lua): the mouse's way into the system menu.
--
-- Pure geometry, so it tests headlessly -- the widget builds no font and loads no image, which is
-- also what lets tests/ui_load_spec.lua require it with no window.
--
-- Worth pinning because this is the mouse-only path. Keyboard has Esc and the pad has Start; if this
-- rectangle is wrong, those two still work and the bug is invisible to anyone testing with a keyboard
-- in their hand. The project standard is that the game is fully playable with the mouse alone.

local BurgerButton = require("ui.burger_button")

return {
    {
        name = "the button covers its own rectangle and nothing outside it",
        fn = function()
            local btn = BurgerButton.new(18, 18)
            assert(btn.w > 0 and btn.h > 0, "the button has no area to click")

            assert(btn:contains(btn.x + btn.w / 2, btn.y + btn.h / 2), "the centre should hit")
            assert(btn:contains(btn.x, btn.y), "the top-left corner should hit")
            assert(btn:contains(btn.x + btn.w, btn.y + btn.h), "the bottom-right corner should hit")

            assert(not btn:contains(btn.x - 1, btn.y), "just left of the button should miss")
            assert(not btn:contains(btn.x, btn.y - 1), "just above the button should miss")
            assert(not btn:contains(btn.x + btn.w + 1, btn.y), "just right of the button should miss")
            assert(not btn:contains(btn.x, btn.y + btn.h + 1), "just below the button should miss")
        end,
    },
    {
        name = "it is anchored where it is put, so the hub can place it in a corner",
        fn = function()
            local btn = BurgerButton.new(200, 120)
            assert(btn.x == 200 and btn.y == 120, "the button moved itself")
            assert(not btn:contains(18, 18), "it should not still be answering for the old corner")
        end,
    },
    {
        name = "only the left button opens the menu",
        fn = function()
            local btn = BurgerButton.new(18, 18)
            local cx, cy = btn.x + btn.w / 2, btn.y + btn.h / 2
            assert(btn:mousepressed(cx, cy, 1), "a left click on it should report a hit")
            assert(not btn:mousepressed(cx, cy, 2), "a right click must not open the menu")
            assert(not btn:mousepressed(cx, cy, 3), "nor a middle click")
        end,
    },
    {
        name = "a left click away from the button reports nothing, so the city still gets it",
        fn = function()
            -- The hub falls through to the building map when this returns false. A button that
            -- claimed every click would make the whole city unclickable.
            local btn = BurgerButton.new(18, 18)
            assert(not btn:mousepressed(640, 400, 1), "a click on the city should not hit the button")
        end,
    },
    {
        name = "hover tracks the pointer in both directions",
        fn = function()
            local btn = BurgerButton.new(18, 18)
            assert(not btn.hovered, "it should not start hovered")
            btn:mousemoved(btn.x + 2, btn.y + 2)
            assert(btn.hovered, "moving onto it should light it")
            btn:mousemoved(640, 400)
            assert(not btn.hovered, "moving away should unlight it -- a stuck highlight is a lie")
        end,
    },
}
