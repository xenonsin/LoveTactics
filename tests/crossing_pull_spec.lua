-- THE CROSSING IS PULLED THROUGH BY HAND (ui/panels/hire_reveal.lua).
--
-- The reveal's middle beat is the one thing in that file a timer cannot carry: the light gathers, and
-- then it WAITS, and nothing else happens until the player takes hold of it and draws it up. Every case
-- below is a rule that beat lives or dies by --
--
--   it waits            no timer walks past the grip. A reveal that advanced on its own would make the
--                       gesture decorative, and a decorative gesture is worse than none.
--   the ball is not     the whole screen skips to the card, which is right for the fortieth crossing
--   the skip            and fatal if the press that TAKES HOLD counts as one. The ball answers first.
--   letting go sinks    a pull abandoned halfway falls back and can be started again. Nothing is lost
--                       by letting go, which is what makes the beat safe to be slow in.
--   the staked pull     the tutorial's crossing (`hold`) cannot be skipped at all, so the pull is the
--   is the lesson       only way through it -- which is exactly where the gesture is taught.
--
-- Fonts are stubbed the way tests/inn_spec.lua stubs them: the panel bakes them in its constructor and
-- love.graphics.newFont throws with no window.

local Character = require("models.character")

local function stubFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function()
        return {
            getHeight = function() return 18 end,
            getWidth = function(_, s) return #tostring(s or "") * 8 end,
            getWrap = function(_, text, _) return text, { text } end,
        }
    end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

-- The rift as the hub opens it: on the descent's own card, which is where the ball's grab target is
-- measured from. `hold` is the tutorial's unskippable crossing.
local RECT = { x = 490, y = 280, w = 300, h = 170 }
local CX, CY = 640, 365

local function openReveal(hold)
    local Reveal = require("ui.panels.hire_reveal")
    local id = "character_knight"
    return Reveal.new({
        result = { id = id, name = "Somebody", char = Character.instantiate(id) },
        rect = RECT,
        hold = hold,
        onClose = function() end,
    })
end

-- Past the gather and into the beat that waits.
local function toGrip(panel)
    for _ = 1, 60 do panel:update(1 / 30) end
    return panel
end

return {
    {
        name = "the light gathers and then waits: no timer walks past the pull",
        fn = function()
            stubFonts(function()
                local panel = toGrip(openReveal())
                assert(panel.phase == "grip", "the reveal advanced on its own to " .. panel.phase)
                assert(panel.pull == 0, "the pull moved with nobody pulling")
            end)
        end,
    },
    {
        name = "taking hold of the ball is not the press that skips",
        fn = function()
            stubFonts(function()
                local panel = toGrip(openReveal())
                panel:mousepressed(CX, CY, 1)
                assert(panel.phase == "grip", "grabbing the light skipped the crossing")
                assert(panel.grab, "the press did not take hold")
            end)
        end,
    },
    {
        name = "a press anywhere else still cuts to the card",
        fn = function()
            stubFonts(function()
                local panel = toGrip(openReveal())
                panel:mousepressed(60, 60, 1)
                assert(panel.phase == "body", "the crossing could not be skipped off the ball")
            end)
        end,
    },
    {
        name = "drawing it the whole way commits, and the rank speaks",
        fn = function()
            stubFonts(function()
                local panel = toGrip(openReveal())
                panel:mousepressed(CX, CY, 1)
                panel:mousemoved(CX, CY - 80)
                assert(panel.phase == "grip", "a half pull let go of the body early")
                assert(panel.pull > 0.4 and panel.pull < 0.7, "half the span is not half the pull")
                panel:mousemoved(CX, CY - 200) -- past the span; clamped
                assert(panel.pull == 1, "the pull did not clamp at the top")
                assert(panel.phase == "tell", "clearing the tear did not start the rank")
            end)
        end,
    },
    {
        name = "letting go short of the top sinks it back, and it can be taken again",
        fn = function()
            stubFonts(function()
                local panel = toGrip(openReveal())
                panel:mousepressed(CX, CY, 1)
                panel:mousemoved(CX, CY - 60)
                panel:mousereleased(CX, CY - 60, 1)
                assert(not panel.grab, "the release did not let go")
                for _ = 1, 60 do panel:update(1 / 30) end
                assert(panel.pull == 0, "the light hung where it was dropped")
                assert(panel.phase == "grip", "an abandoned pull carried the crossing anyway")

                panel:mousepressed(CX, CY, 1)
                panel:mousemoved(CX, CY - 200)
                assert(panel.phase == "tell", "the second attempt was refused")
            end)
        end,
    },
    {
        name = "the staked crossing cannot be skipped, so the pull is the only way through it",
        fn = function()
            stubFonts(function()
                local panel = toGrip(openReveal(true))
                panel:mousepressed(60, 60, 1)
                panel:keypressed("escape")
                assert(panel.phase == "grip", "the tutorial's crossing was skippable")
                panel:mousepressed(CX, CY, 1)
                panel:mousemoved(CX, CY - 200)
                assert(panel.phase == "tell", "the staked crossing refused its own pull")
            end)
        end,
    },
}
