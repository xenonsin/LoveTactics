local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")

function love.load(args)
    -- Headless test entry: `& "E:\LOVE\lovec.exe" . test`
    if args and args[1] == "test" then
        local ok = require("tests.runner").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    Scale.resize(love.graphics.getDimensions())
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

-- Mouse callbacks arrive in real window coordinates; convert the position (and
-- any deltas) into the logical space the states and widgets are authored in.
local function forwardMouse(name)
    love[name] = function(x, y, a, b, c)
        InputMode.set("mouse")
        local state = State.current
        if state and state[name] then
            local gx, gy = Scale.toGame(x, y)
            return state[name](gx, gy, a, b, c)
        end
    end
end

love.draw = function()
    Scale.start()
    local state = State.current
    if state and state.draw then state.draw() end
    Scale.finish()
end

love.resize = function(w, h)
    Scale.resize(w, h)
    local state = State.current
    if state and state.resize then state.resize(w, h) end
end

-- mousemoved also carries (dx, dy) deltas in real pixels; scale them too.
love.mousemoved = function(x, y, dx, dy, istouch)
    InputMode.set("mouse")
    local state = State.current
    if state and state.mousemoved then
        local gx, gy = Scale.toGame(x, y)
        return state.mousemoved(gx, gy, dx / Scale.scale, dy / Scale.scale, istouch)
    end
end

-- F11 toggles fullscreen (desktop mode) so the game fills a 1920x1080 display;
-- everything else routes to the current state.
love.keypressed = function(key, ...)
    InputMode.set("keyboard")
    if key == "f11" then
        local full = love.window.getFullscreen()
        love.window.setFullscreen(not full, "desktop")
        Scale.resize(love.graphics.getDimensions())
        return
    end
    local state = State.current
    if state and state.keypressed then
        return state.keypressed(key, ...)
    end
end

-- The wheel is a mouse gesture; a pad button/stick means the player picked up the gamepad. Each
-- updates the shared InputMode so on-screen prompts show the matching glyphs (see input_mode.lua).
love.wheelmoved = function(x, y)
    InputMode.set("mouse")
    local state = State.current
    if state and state.wheelmoved then return state.wheelmoved(x, y) end
end

love.gamepadpressed = function(joystick, button)
    InputMode.set("gamepad")
    local state = State.current
    if state and state.gamepadpressed then return state.gamepadpressed(joystick, button) end
end

love.gamepadaxis = function(joystick, axis, value)
    InputMode.axis(value) -- switches to gamepad only past the deadzone (ignores stick drift)
    local state = State.current
    if state and state.gamepadaxis then return state.gamepadaxis(joystick, axis, value) end
end

forward("update")
forwardMouse("mousepressed")
forwardMouse("mousereleased")
forward("keyreleased")
forward("textinput")
forward("gamepadreleased")
