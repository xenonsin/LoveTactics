function love.conf(t)
    t.window.title = "Project Tactics"

    -- Names the save directory love.filesystem writes into (see models/save.lua).
    -- Without it there is no write directory and every save silently fails.
    t.identity = "lovetactics"
    -- Real window size. The game is authored in a fixed 1280x720 logical space
    -- (see scale.lua) and letterbox-scaled to whatever size the window is, so
    -- this is just the initial size -- the window is freely resizable and scales
    -- cleanly up to 1920x1080 and beyond. 1280x720 is a 1:1 start (no scaling).
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360

    -- Rasterise at the DISPLAY's real pixel density, not the window's logical one.
    --
    -- Without this a phone browser hands the engine an 844x390 drawable for a 2532x1170 screen: the
    -- 1280x720 logical space is fitted at 0.54 -- a DOWNSCALE, an 11px glyph rasterised into six
    -- pixels -- and the browser then blows that up threefold to fill the display. Text arrives at
    -- about a fifth of the resolution the screen can show, which is most of why the web build was
    -- illegible on a handset. With it the same fit is 1.63, an upscale, and text is sharp.
    --
    -- The density is the RASTERISER's business and nobody else's. LOVE keeps drawing in window
    -- units and applies the scale itself, so scale.lua fits, offsets and scissors in those units
    -- throughout (it must not mix in pixels -- that draws the frame three times too large and off
    -- the side of the screen); its compositing canvas carries the density explicitly, and
    -- ui/theme.lua bakes its glyph atlases against it. On a display whose density is 1 -- an
    -- ordinary desktop monitor -- every one of those numbers is what it always was.
    t.window.highdpi = true

    -- Run headless (no window) for every console subcommand that only prints: `lovec . test`,
    -- `lovec . balance-report`, and friends (the dispatch ladder lives in main.lua).
    --
    -- Scans the WHOLE argument list rather than testing arg[#arg]. The old check only saw the
    -- last argument, so it worked for a bare `test` and for nothing else: every tool that takes
    -- an argument of its own -- `progression-report full`, `test balance` -- opened a 1280x720
    -- window, flashed it, and tore it down.
    --
    -- The icon and character composers are deliberately ABSENT: they draw through
    -- love.graphics to build their atlases and need a real GL context.
    local HEADLESS = {
        ["test"] = true,
        ["extract-strings"] = true,
        ["art-report"] = true,
        ["audio-report"] = true,
        ["audio-commission"] = true,
        ["progression-report"] = true,
        ["balance-report"] = true,
        ["balance-rescale"] = true,
        ["curve-migrate"] = true,
        ["curve-widen"] = true,
    }
    for _, a in ipairs(arg or {}) do
        if HEADLESS[a] then
            t.window = false
            break
        end
    end
end
