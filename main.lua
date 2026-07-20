local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")
local Cursor = require("ui.cursor")
local Conversation = require("models.conversation")

function love.load(args)
    -- Headless test entry: `& "E:\LOVE\lovec.exe" . test`
    if args and args[1] == "test" then
        local ok = require("tests.runner").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Localization string extraction: `& "E:\LOVE\lovec.exe" . extract-strings`
    -- Stamps stable ids into conversations and regenerates data/lang/*.lua. See tools/extract_strings.
    if args and args[1] == "extract-strings" then
        require("tools.extract_strings").run()
        love.event.quit(0)
        return
    end

    Scale.resize(love.graphics.getDimensions())

    -- Two-window duel harness, for developing the netplay protocol against a real socket:
    --   love . duel host [auto]      (window 1, listens)
    --   love . duel join [auto]      (window 2, connects)
    -- `auto` makes each side play itself, so a whole duel can be run and the two fingerprints
    -- compared without a human at each window.
    --
    -- Development only. Gated here on models/debug.lua, and the transport it needs is registered
    -- only for a debug build (models/transport.lua), so a release cannot reach it either way. A
    -- shipped game matches through Steam.
    if args and args[1] == "duel" then
        if not require("models.debug").enabled then
            print("the duel harness is available in development builds only")
            love.event.quit(1)
            return
        end
        State.switch(require("states.duel_debug"), args[2] or "host", args[3], tonumber(args[4]))
        return
    end

    if args and args[1] == "shot" then
        love.filesystem.setIdentity("lovetactics_verify")
        print("SAVEDIR: " .. love.filesystem.getSaveDirectory())
        State.switch(require("states.debug_editor"))
        return
    end
    State.switch(require("states.menu"))
end

-- A conversation is a GLOBAL overlay (models/conversation.lua), not a state's panel: while one
-- plays, every callback below routes to it and NOT to the current state, so whatever is running
-- (the hub, the overworld, a battle mid-turn) is frozen and resumes in place when it ends. See
-- the header of models/conversation.lua.

-- Forward a callback to the current state, unless a conversation is up (then the state is frozen
-- and the event is swallowed -- these are the callbacks the overlay does not consume).
local function forward(name)
    love[name] = function(...)
        if Conversation.active then return end
        local state = State.current
        if state and state[name] then
            return state[name](...)
        end
    end
end

-- Mouse callbacks arrive in real window coordinates; convert the position (and any deltas) into
-- the logical space the states and widgets are authored in, then route to the overlay or state.
local function forwardMouse(name)
    love[name] = function(x, y, a, b, c)
        InputMode.set("mouse")
        local gx, gy = Scale.toGame(x, y)
        local overlay = Conversation.active
        if overlay then
            if overlay[name] then overlay[name](overlay, gx, gy, a, b, c) end
            return
        end
        local state = State.current
        if state and state[name] then
            return state[name](gx, gy, a, b, c)
        end
    end
end

love.update = function(dt)
    local overlay = Conversation.active
    if overlay then
        if overlay.update then overlay:update(dt) end
        return
    end
    local state = State.current
    if state and state.update then return state.update(dt) end
end

love.draw = function()
    Scale.start()
    local state = State.current
    if state and state.draw then state.draw() end
    -- The conversation overlay draws ON TOP of the (frozen) state, so the scene shows behind it.
    local overlay = Conversation.active
    if overlay and overlay.draw then overlay:draw() end
    -- Context cursor: while the mouse is the active device, hide the OS pointer and draw our own
    -- glyph, chosen by the overlay's (else the state's) optional cursorKind(x, y). The mouse
    -- position -- already in the logical 1280x720 space -- is handed in so hit-testing needs no
    -- extra tracking. Drawn inside the scale transform so it shares that space.
    if InputMode.isMouse() then
        love.mouse.setVisible(false)
        local gx, gy = Scale.toGame(love.mouse.getPosition())
        local kind
        if overlay and overlay.cursorKind then
            kind = overlay:cursorKind(gx, gy)
        elseif state and state.cursorKind then
            kind = state:cursorKind(gx, gy)
        end
        Cursor.draw(kind or "arrow", gx, gy)
    else
        love.mouse.setVisible(true) -- keyboard/gamepad: leave the OS arrow available
    end
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
    local gx, gy = Scale.toGame(x, y)
    local sdx, sdy = dx / Scale.scale, dy / Scale.scale
    local overlay = Conversation.active
    if overlay then
        if overlay.mousemoved then overlay:mousemoved(gx, gy, sdx, sdy, istouch) end
        return
    end
    local state = State.current
    if state and state.mousemoved then
        return state.mousemoved(gx, gy, sdx, sdy, istouch)
    end
end

-- F11 toggles fullscreen (desktop mode) so the game fills a 1920x1080 display; it stays global
-- even during a conversation. Everything else routes to the overlay (if any) or the state.
love.keypressed = function(key, ...)
    InputMode.set("keyboard")
    if key == "f11" then
        local full = love.window.getFullscreen()
        love.window.setFullscreen(not full, "desktop")
        Scale.resize(love.graphics.getDimensions())
        return
    end
    local overlay = Conversation.active
    if overlay then
        if overlay.keypressed then overlay:keypressed(key, ...) end
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
    if Conversation.active then return end
    local state = State.current
    if state and state.wheelmoved then return state.wheelmoved(x, y) end
end

love.gamepadpressed = function(joystick, button)
    InputMode.set("gamepad")
    local overlay = Conversation.active
    if overlay then
        if overlay.gamepadpressed then overlay:gamepadpressed(joystick, button) end
        return
    end
    local state = State.current
    if state and state.gamepadpressed then return state.gamepadpressed(joystick, button) end
end

love.gamepadaxis = function(joystick, axis, value)
    InputMode.axis(value) -- switches to gamepad only past the deadzone (ignores stick drift)
    if Conversation.active then return end
    local state = State.current
    if state and state.gamepadaxis then return state.gamepadaxis(joystick, axis, value) end
end

do
    local baseDraw, frame = love.draw, 0
    love.draw = function()
        baseDraw()
        if not love.filesystem.getIdentity():match("verify") then return end
        frame = frame + 1
        if frame == 2 then
            local ed = require("states.debug_editor")
            ed.mousepressed(913, 171, 1)  -- Type: weapon
            ed.mousepressed(973, 171, 1)  -- Type: armor
            ed.mousepressed(1149, 195, 1) -- Class: mage
            ed.mousemoved(1149, 195, 0, 0)
        elseif frame == 4 then
            love.graphics.captureScreenshot("shot.png")
        elseif frame == 8 then
            love.event.quit(0)
        end
    end
end

forwardMouse("mousepressed")
forwardMouse("mousereleased")
forward("keyreleased")
forward("textinput")
forward("gamepadreleased")
