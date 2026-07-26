local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")
local Cursor = require("ui.cursor")
local Conversation = require("models.conversation")
local ScreenFx = require("ui.screen_fx")

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

    -- Art-debt report: `& "E:\LOVE\lovec.exe" . art-report [missing]`
    -- Counts referenced-vs-present art per bucket. See tools/art_report and docs/art-assets.md.
    if args and args[1] == "art-report" then
        require("tools.art_report").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Audio-debt report: `& "E:\LOVE\lovec.exe" . audio-report [missing]`
    -- Counts declared cues (data/sounds.lua) against what is on disk. See tools/audio_report.
    if args and args[1] == "audio-report" then
        require("tools.audio_report").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Icon pipeline: `. icon-map [unmatched]` proposes a game-icons.net icon for each icon-shaped
    -- asset; `. icon-build` renders the mapping into assets/. Run tools/icons/fetch.ps1 first.
    if args and args[1] == "icon-map" then
        require("tools.icon_map").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    if args and args[1] == "icon-build" then
        require("tools.icon_build").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Icon COMPOSER (prototype): `. icon-compose [all]` draws each icon from the blueprint's own tags
    -- (family + element + class + tier) into vendor/compose-preview/, never assets/. The permanent
    -- form of the pipeline above -- see docs/art-assets.md, "The permanent icon system".
    if args and args[1] == "icon-compose" then
        require("tools.icon_compose").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Character-token COMPOSER: `. char-compose [assets [force]]` draws a board token from each
    -- character blueprint's own fields (kind + class + element + boss) into vendor/compose-preview/chars/,
    -- or into assets/chars/ with `assets` (skipping ids that already have real art). The item composer,
    -- one register up -- see tools/char_compose and docs/art-assets.md, "Composed tokens for characters".
    if args and args[1] == "char-compose" then
        require("tools.char_compose").run({ select(2, unpack(args)) })
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
    -- The screen-effect decays advance on REAL dt, always -- before the conversation short-circuit and
    -- untouched by any hit-stop, so a freeze the battle imposes on itself still lets its own shake and
    -- flash run down (ui/screen_fx.lua). A state that wants the freeze applies ScreenFx.timeScale() to
    -- its own gameplay dt (states/battle.lua); everything else ignores it.
    ScreenFx.update(dt)
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
