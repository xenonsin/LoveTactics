-- A HELD KEY MUST NOT DRIVE A SCENE (ui/dialogue.lua's keypressed guard).
--
-- The failure this pins is a one-time scene spent by the keypress that OPENED it: Enter walks into the
-- card the city is coaching, the house plays its first-visit greeting, and LOVE's key repeats -- the
-- same physical press, still down -- confirm their way through the whole thing. Measured on the
-- Undercroft before the guard: twelve repeats spent the greeting, four more the counter scene.
-- models/vendor_visit.lua records the visit BEFORE the greeting plays, so what is skipped is gone.
--
-- IT IS TWO ASSERTIONS AND THEY ARE ABOUT DIFFERENT THINGS. One is the guard, asked of the widget; the
-- other is the WIRING -- main.lua has to hand the repeat flag on for the guard to have anything to read,
-- and a forwarder trimmed back to `overlay:keypressed(key)` would leave the guard green and dead.

local Conversation = require("models.conversation")
local Dialogue = require("ui.dialogue")

-- An overlay standing in for a live scene: every verb the key handler can reach, counted. A stub rather
-- than a real Dialogue because a real one news fonts, and the headless runner has no window.
local function overlay()
    local o = { finished = 0, confirmed = 0, moved = 0, sawRepeat = nil }
    function o:finish() self.finished = self.finished + 1 end
    function o:confirm() self.confirmed = self.confirmed + 1 end
    function o:moveChoice() self.moved = self.moved + 1 end
    function o:openSource() end
    return o
end

-- Play `fn` with `o` standing in as the live conversation overlay, and put the global back afterwards
-- however it goes -- a spec that raises with one still set hands the next spec a frozen game.
local function asActive(o, fn)
    local before = Conversation.active
    Conversation.active = o
    local ok, err = pcall(fn)
    Conversation.active = before
    if not ok then error(err, 0) end
end

return {
    {
        name = "a key REPEAT does not advance, skip or steer a scene",
        fn = function()
            local o = overlay()
            for _, key in ipairs({ "return", "kpenter", "space", "escape", "up", "down" }) do
                Dialogue.keypressed(o, key, key, true)
            end
            assert(o.confirmed == 0, "a held key advanced the scene")
            assert(o.finished == 0, "a held key skipped the scene")
            assert(o.moved == 0, "a held key walked the choice list")
        end,
    },
    {
        name = "a real press still advances, skips and steers",
        fn = function()
            local o = overlay()
            Dialogue.keypressed(o, "return", "return", false)
            Dialogue.keypressed(o, "down", "down", false)
            Dialogue.keypressed(o, "escape", "escape", false)
            assert(o.confirmed == 1, "Enter did not advance the scene")
            assert(o.moved == 1, "Down did not walk the choice list")
            assert(o.finished == 1, "Esc did not skip the scene")
            -- ...and a press with no repeat flag at all (an internal caller, a test, a retrofitted
            -- forwarder) reads as a press rather than as a repeat.
            Dialogue.keypressed(o, "return")
            assert(o.confirmed == 2, "a bare keypress was dropped")
        end,
    },
    {
        name = "main.lua hands the repeat flag to the overlay",
        fn = function()
            local o = overlay()
            function o:keypressed(key, scancode, isrepeat)
                self.sawRepeat = isrepeat
                self.lastKey = key
            end
            asActive(o, function() love.keypressed("return", "return", true) end)
            assert(o.lastKey == "return", "the overlay was not handed the key at all")
            assert(o.sawRepeat == true, "main.lua dropped isrepeat; the guard in ui/dialogue is dead")
        end,
    },
}
