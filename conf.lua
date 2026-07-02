function love.conf(t)
    t.window.title = "LoveTactics"
    t.window.width = 800
    t.window.height = 600

    -- Run headless (no window) when launched for the test suite: `lovec . test`
    if arg and arg[#arg] == "test" then
        t.window = false
    end
end
