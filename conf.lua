function love.conf(t)
    t.window.title = "LoveTactics"

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
