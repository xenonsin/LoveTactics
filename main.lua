local State = require("states")

function love.load(args)
    -- Headless test entry: `& "E:\LOVE\lovec.exe" . test`
    if args and args[1] == "test" then
        local ok = require("tests.runner").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    State.switch(require("states.menu"))
end

-- Forward each LÖVE callback to the current state, if it defines one.
local function forward(name)
    love[name] = function(...)
        local state = State.current
        if state and state[name] then
            return state[name](...)
        end
    end
end

forward("update")
forward("draw")
forward("keypressed")
forward("keyreleased")
forward("mousepressed")
forward("mousereleased")
forward("mousemoved")
forward("wheelmoved")
forward("textinput")
forward("gamepadpressed")
forward("gamepadreleased")
forward("gamepadaxis")
