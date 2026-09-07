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
}
