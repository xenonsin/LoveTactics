-- The runtime layout rule (scale.lua): which arrangement a given window is big enough for.
--
-- The rule is the cheap half of the handheld work and lands before the layout it selects, so these
-- are the only thing standing between it and a silent regression -- there is no second arrangement
-- registered yet for a wrong answer to show up in.

local Scale = require("scale")

-- Every case restores what it touched: Scale is a singleton the whole suite shares.
local function withScale(fn)
    local w, h = Scale.windowW, Scale.windowH
    local hand, force = Scale.handheld, Scale.forceHandheld
    local ok, err = pcall(fn)
    Scale.handheld, Scale.forceHandheld = hand, force
    if w then Scale.resize(w, h) end
    assert(ok, err)
end

return {
    {
        name = "a desktop window keeps the desktop arrangement, a phone-shaped one does not",
        fn = function()
            withScale(function()
                Scale.forceHandheld = false
                Scale.handheld = false
                assert(not Scale.wantsHandheld(1920, 1080), "1080p is not a handheld")
                assert(not Scale.wantsHandheld(1280, 720), "720p is not a handheld")
                assert(not Scale.wantsHandheld(1024, 576), "1024x576 is exactly the threshold and stays desktop")
                assert(Scale.wantsHandheld(800, 450), "a 800x450 window is under the glance floor")
                assert(Scale.wantsHandheld(844, 390), "a phone in landscape is a handheld")
            end)
        end,
    },
    {
        -- The trap this exists to catch: measuring against the LIVE space would make the answer
        -- depend on the previous answer, and the arrangement would oscillate every frame.
        name = "the fit is measured against the desktop space, whatever is live",
        fn = function()
            withScale(function()
                local before = Scale.layoutFit(844, 390)
                local w, h = Scale.WIDTH, Scale.HEIGHT
                Scale.WIDTH, Scale.HEIGHT = 1168, 540 -- pretend the handheld space went live
                local after = Scale.layoutFit(844, 390)
                Scale.WIDTH, Scale.HEIGHT = w, h
                assert(math.abs(before - after) < 1e-9,
                    "layoutFit read the live space -- the rule will oscillate")
            end)
        end,
    },
    {
        name = "the deadband makes leaving cost more than entering",
        fn = function()
            withScale(function()
                Scale.forceHandheld = false
                -- A fit of 0.85 sits between the two thresholds: it holds whichever side it is on.
                local w, h = 1088, 612 -- 1088/1280 = 0.85, 612/720 = 0.85
                Scale.handheld = false
                assert(not Scale.wantsHandheld(w, h), "coming from desktop, 0.85 stays desktop")
                Scale.handheld = true
                assert(Scale.wantsHandheld(w, h), "coming from handheld, 0.85 stays handheld")
            end)
        end,
    },
    {
        -- A Switch is 1280x720 at fit 1.0 and reads as a desktop to the arithmetic; its pixels are
        -- half the angular size of a CSS pixel's. The only way it can be known is to be told.
        name = "a screen that declares itself a handheld is one at any size",
        fn = function()
            withScale(function()
                Scale.forceHandheld = true
                assert(Scale.wantsHandheld(1280, 720), "a declared handheld is one at 720p")
                assert(Scale.wantsHandheld(1920, 1080), "...and at 1080p docked")
            end)
        end,
    },
    {
        name = "a resize answers the rule, and main.lua declares a handheld build",
        fn = function()
            withScale(function()
                Scale.forceHandheld = false
                Scale.handheld = false
                Scale.resize(1920, 1080)
                assert(Scale.handheld == false, "1080p left the flag set")
                Scale.resize(844, 390)
                assert(Scale.handheld == true, "a phone-shaped window did not set the flag")
            end)
            local src = assert(love.filesystem.read("main.lua"), "main.lua is readable")
            assert(src:find("Scale%.forceHandheld%s*="),
                "main.lua never declares a handheld build, so a Switch would read as a desktop")
        end,
    },
    {
        -- The point of the handheld space: on a phone the HEIGHT term wins the fit, so width is free.
        -- Fixing the height at 540 and running the width out to the device's aspect buys the
        -- legibility of a 960-wide space AND more panel room than the desktop has.
        name = "a handheld space is short, and as wide as the screen will allow",
        fn = function()
            withScale(function()
                Scale.forceHandheld = false
                Scale.handheld = false

                Scale.resize(1920, 1080)
                assert(Scale.WIDTH == 1280 and Scale.HEIGHT == 720,
                    "a desktop must stay on the authored space")

                Scale.resize(844, 390) -- the measured handset, landscape
                assert(Scale.HEIGHT == 540, "the handheld space fixes the height at 540")
                assert(Scale.WIDTH == 1168,
                    "the width must follow the device's own aspect -- got " .. Scale.WIDTH)
                -- ...and the whole reason for it: no bars, where the authored space wasted 18%.
                local fit = math.min(844 / Scale.WIDTH, 390 / Scale.HEIGHT)
                assert(math.abs(844 - Scale.WIDTH * fit) < 2,
                    "the fitted width does not fill the screen -- the bars are still there")
            end)
        end,
    },
    {
        name = "the handheld width is clamped, so no screen can ask for a shape nothing is authored for",
        fn = function()
            withScale(function()
                Scale.forceHandheld = true
                Scale.resize(1024, 768) -- 4:3, which would want a 720-wide space
                assert(Scale.WIDTH == 960, "a squarer screen must clamp up to 960, got " .. Scale.WIDTH)
                Scale.resize(2560, 720) -- ultrawide, which would want 1920
                assert(Scale.WIDTH == 1280, "an ultrawide must clamp down to 1280, got " .. Scale.WIDTH)
            end)
        end,
    },
    {
        -- data/buildings positions every hub door by hand in the authored space, and the city art
        -- behind them is stretched to the live one -- so the two axes must scale INDEPENDENTLY or a
        -- hotspot drifts off the door it names.
        name = "an authored rect travels into the live space on both axes",
        fn = function()
            withScale(function()
                Scale.forceHandheld = false
                Scale.handheld = false
                Scale.resize(1280, 720)
                local x, y, w, h = Scale.fromAuthored(815, 413, 270, 130)
                assert(x == 815 and y == 413 and w == 270 and h == 130,
                    "the authored space must be the identity on a desktop")

                Scale.forceHandheld = true
                Scale.resize(844, 390)
                x, y, w, h = Scale.fromAuthored(815, 413, 270, 130)
                local kx, ky = Scale.WIDTH / 1280, Scale.HEIGHT / 720
                assert(math.abs(x - 815 * kx) < 1e-9 and math.abs(w - 270 * kx) < 1e-9,
                    "the x axis did not follow the space")
                assert(math.abs(y - 413 * ky) < 1e-9 and math.abs(h - 130 * ky) < 1e-9,
                    "the y axis did not follow the space")
                assert(math.abs(kx - ky) > 0.01,
                    "this test proves nothing unless the two axes actually differ")
            end)
        end,
    },
    {
        -- Almost nothing caches geometry -- 65 files read Scale.WIDTH at draw time -- but the few
        -- that do need to be able to notice, and a counter that ticks when nothing moved is a
        -- rebuild every frame.
        name = "the space epoch moves only when the space does",
        fn = function()
            withScale(function()
                Scale.forceHandheld = false
                Scale.handheld = false
                Scale.resize(1920, 1080)
                local e = Scale.spaceEpoch
                Scale.resize(1600, 900) -- same space, different window
                assert(Scale.spaceEpoch == e, "the epoch moved without the space changing")
                Scale.resize(844, 390)  -- now the space really changes
                assert(Scale.spaceEpoch > e, "the epoch did not move when the space did")
            end)
        end,
    },
}
