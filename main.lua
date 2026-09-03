local State = require("states")
local Scale = require("scale")
local InputMode = require("input_mode")
local Cursor = require("ui.cursor")
local Conversation = require("models.conversation")
local ScreenFx = require("ui.screen_fx")

function love.load(args)
    -- Headless test entry: `& "E:\LOVE\lovec.exe" . test [pattern]`
    -- The optional pattern narrows the run to specs whose name contains it (`test balance`),
    -- which is what makes a data pass that has to fix up fixtures survivable. See tests/runner.
    if args and args[1] == "test" then
        -- Silence playback for the run. Real audio now exists and love.audio is live under the headless
        -- runner (t.window = false drops the window, not the audio device), so any cue a test fires would
        -- play OUT LOUD. Muting the device master keeps every guard and Source path exercised -- the
        -- sources still load and play, at zero gain -- while emitting nothing. See tests/sound_spec.lua.
        if love.audio and love.audio.setVolume then love.audio.setVolume(0) end
        local ok = require("tests.runner").run(args[2])
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

    -- Art BUILD: `& "E:\LOVE\lovec.exe" . art-build [overlay | stale]`
    -- Regenerates every composed icon and token unconditionally, then copies art/ over assets/ so drawn
    -- art wins by landing second. `stale` fails when assets/ is behind its inputs. See tools/art_build.
    if args and args[1] == "art-build" then
        require("tools.art_build").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Content reachability: `& "E:\LOVE\lovec.exe" . content-report [full]`
    -- Which authored scenes a live route can actually play, asked through the model layer rather than
    -- read off the call sites. Splits live / parked (the retired Quest Board) / orphan. See
    -- tools/content_report -- and its header for the deletion that made it necessary.
    if args and args[1] == "content-report" then
        require("tools.content_report").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Silhouette SOURCE audit: `& "E:\LOVE\lovec.exe" . art-source [slugs | credits | ship]`
    -- Which set answers each slug the shipped composers draw -- art/bases/ (ours) vs vendor/game-icons
    -- (CC BY, dev only). `ship` exits nonzero while any vendored slug remains. See tools/art_source.
    if args and args[1] == "art-source" then
        require("tools.art_source").run({ select(2, unpack(args)) })
        return -- art-source sets its own exit code for the ship gate
    end

    -- (`progression-report` stood here and is GONE WITH THE QUEST BOARD. It walked Quest.available
    -- under two play policies -- "commit to one house" and "round-robin the houses" -- and both of those
    -- are choices a player made at the board. A descent seats work on its floors; there is no policy to
    -- walk. What it measured is still worth measuring, and an errand-pool version of it would be a new
    -- tool asking a different question: what arrives as a company goes DOWN, not as it picks.)

    -- Balance ledger: `& "E:\LOVE\lovec.exe" . balance-report [full | sim [n]]`
    -- Measures the game's two number scales against each other: what the reference loadout throws at
    -- each prestige, what every body subtracts from it, and how many hits that is in both directions.
    -- Reports what floors, what dominates the player outright, and what cannot hurt them back. The
    -- instrument behind docs/balance.md. See tools/balance_report.
    if args and args[1] == "balance-report" then
        require("tools.balance_report").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Grade ledger: `& "E:\LOVE\lovec.exe" . grade-report [full | diff | explain ID]`
    -- Ranks every item by what it is actually worth (models/grade.lua) -- read without looking at its
    -- slot or its price, both of which are downstream of the grade -- and says where the shelf
    -- disagrees. Reports only; the rewrite is a separate pass. See tools/grade_report.
    -- Drop tiers: & "E:/LOVE/lovec.exe" . drop-tier [apply]
    -- An unpriced item has no shelf to sit on, so its grade sets the DEPTH the rift gives it up
    -- at instead (models/spoils.lua). Reports only unless told to apply. See tools/drop_tier.
    if args and args[1] == "drop-tier" then
        require("tools.drop_tier").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    if args and args[1] == "grade-report" then
        require("tools.grade_report").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- The class fold: `& "E:\LOVE\lovec.exe" . class-fold [creature] [apply]`
    -- Collapses `class` and `discipline` onto one taxonomy of 46 classes -- the default pass moves an
    -- item's discipline into its class, `creature` buckets the kit that belongs to no job. Dry run by
    -- default. See docs/class-fold.md and tools/class_fold.
    if args and args[1] == "class-fold" then
        require("tools.class_fold").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- ...and its last step: `& "E:\LOVE\lovec.exe" . class-rename [apply]`
    -- The module and folder that own the 46 classes stop being called disciplines. No behaviour.
    -- Dry run by default. See tools/class_rename.
    if args and args[1] == "class-rename" then
        require("tools.class_rename").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Balance rescale: `& "E:\LOVE\lovec.exe" . balance-rescale [N] [apply]`
    -- Brings blueprint magnitudes into the band tests/balance_spec.lua enforces, in four passes
    -- (armour, defense, attack, mirror). Dry run by default. See tools/balance_rescale.
    if args and args[1] == "balance-rescale" then
        require("tools.balance_rescale").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Day migration: `& "E:\LOVE\lovec.exe" . day-migrate [apply]`
    -- Rewrites the difficulty half of prestige onto the calendar across the data layer -- `ctx.prestige`
    -- in composition functions and `minPrestige` gates. Dry run by default. See tools/day_migrate and
    -- models/calendar.lua on the two jobs prestige was doing.
    if args and args[1] == "day-migrate" then
        require("tools.day_migrate").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- One board, drawn: `& "E:\LOVE\lovec.exe" . board-render [biome] [seed]`
    -- Dumps a single rolled board as ground and again as fightability, because the layout work is six
    -- carve algorithms that will be wrong in a SHAPE, and a mean cannot show you a shape. See
    -- tools/board_render.
    if args and args[1] == "board-render" then
        require("tools.board_render").run({ select(2, unpack(args)) })
        if love.event then love.event.quit(0) end
        return
    end

    -- Board ledger: `& "E:\LOVE\lovec.exe" . board-report [n] [all | biome=ID] [tiers]`
    -- Rolls n overworld boards and reports what the generator laid down -- whether a fight can even
    -- happen on the ground it was seated on, boons per fight, how many ended up guarded, rest density,
    -- and the tier arc by fifth. `all` prints one row per ground. The instrument behind
    -- docs/overworld.md's composition knobs. See tools/board_report.
    if args and args[1] == "board-report" then
        require("tools.board_report").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- (`biome-report` stood here and is GONE WITH THE QUEST BOARD. It walked the forty-day season table
    -- asking whether every open ground held live work -- a question about which GROUNDS a morning
    -- offered, which was the board's whole job. The descent picks its ground from the circle it is on
    -- (models/descent.lua's SINS), so there is no schedule left to tune.)

    -- Curve migration: `& "E:\LOVE\lovec.exe" . curve-migrate [apply | snapshot PATH]`
    -- Rewrites hand-typed per-level rows in data/items as models/curve.lua generator calls, and dumps
    -- every resolved magnitude for before/after diffing. Dry run by default. See tools/curve_migrate.
    if args and args[1] == "curve-migrate" then
        require("tools.curve_migrate").run({ select(2, unpack(args)) })
        love.event.quit(0)
        return
    end

    -- Curve widening: `& "E:\LOVE\lovec.exe" . curve-widen [apply | dead]`
    -- Retunes data/items magnitudes so every forge level a player pays for actually moves a number: a
    -- growth axis climbs a point per level, and a magnitude too small to do that goes flat instead of
    -- stuttering. `dead` reports items that still buy nothing at some level. Dry run by default.
    -- See tools/curve_widen and models/curve.lua's span rule.
    if args and args[1] == "curve-widen" then
        require("tools.curve_widen").run({ select(2, unpack(args)) })
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

    -- Audio COMMISSION doc: `& "E:\LOVE\lovec.exe" . audio-commission`
    -- Generates docs/audio-commission.md from data/sounds.lua (each cue's length + desc). See
    -- tools/audio_commission and docs/audio-assets.md.
    if args and args[1] == "audio-commission" then
        require("tools.audio_commission").run()
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

    -- Icon COMPOSER: `. icon-compose [all]` draws each icon from the blueprint's own tags
    -- (family + element + class + tier) into vendor/compose-preview/ (never assets/); `. icon-compose
    -- assets` graduates it, writing each item's own sprite path in assets/. The permanent form of the
    -- pipeline above -- see docs/art-assets.md, "The permanent icon system".
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

    -- PARSE-ONLY: `& "E:\LOVE\lovec.exe" . parse [path ...]`
    --
    -- Loads each file WITHOUT running it and reports the first syntax error, or checks every .lua in the
    -- tree when given no paths. Exit 0 clean, 1 on the first failure.
    --
    -- IT EXISTS BECAUSE THE SUITE IS THE ONLY PARSER OTHERWISE, and it takes two and a half minutes. A
    -- session spent five full gate cycles diagnosing five syntax errors -- each one a stray `end` or a
    -- duplicated `{` left by a bad line-range edit -- and every one of them would have been named in
    -- seconds by this. `luac` is not installed; LÖVE has always been able to do it.
    if args and args[1] == "parse" then
        local paths, bad = {}, 0
        for i = 2, #args do paths[#paths + 1] = args[i] end
        if #paths == 0 then
            local function walk(dir)
                for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
                    local p = (dir == "" and name) or (dir .. "/" .. name)
                    local info = love.filesystem.getInfo(p)
                    if info and info.type == "directory" then
                        if name ~= ".git" and name ~= "vendor" then walk(p) end
                    elseif p:match("%.lua$") then paths[#paths + 1] = p end
                end
            end
            walk("")
        end
        -- pcall'd, and that is not belt-and-braces: love.filesystem.load RAISES on a syntax error rather
        -- than returning nil plus a message, so an unguarded call hands the bad file straight to LÖVE's
        -- error handler -- which draws it to a window nobody is watching and waits. A checker that hangs
        -- on exactly the input it exists to catch is worse than no checker.
        for _, p in ipairs(paths) do
            local ok, chunk, err = pcall(love.filesystem.load, p)
            if not ok then err = chunk chunk = nil end
            if not chunk then print("PARSE " .. p .. ": " .. tostring(err)) bad = bad + 1 end
        end
        print(string.format("parse: %d file(s), %d bad", #paths, bad))
        love.event.quit(bad > 0 and 1 or 0)
        return
    end

    -- A SCREENSHOT HARNESS, and development only -- gated exactly as the duel harness above is
    -- (models/debug.lua is a build constant). It boots straight past the menu so a screen can be driven
    -- and captured; `.claude/skills/verify` rewrites the body of this branch for whatever it needs to
    -- look at, and reverts. A shipping build has no reason to carry an entry point that skips the game.
    if args and args[1] == "shot" then
        if not require("models.debug").enabled then
            print("the screenshot harness is available in development builds only")
            love.event.quit(1)
            return
        end
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

forwardMouse("mousepressed")
forwardMouse("mousereleased")
forward("keyreleased")
forward("textinput")
forward("gamepadreleased")
