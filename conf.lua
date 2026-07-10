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

    -- Run headless (no window) when launched for the test suite: `lovec . test`
    if arg and arg[#arg] == "test" then
        t.window = false
    end
end
