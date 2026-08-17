-- SUPERSEDED, AND PARKED RATHER THAN DELETED. Nothing reaches this file.
--
-- It was the descent's front screen while the descent was a MODE: chosen from the title screen, run on
-- a throwaway company in a save file of its own, banking nothing. The mode was then promoted to being
-- the game -- character creation and the prologue are its on-ramp, the capital is its town, and a
-- sponsor at the gate is what sends you down (states/gate.lua, reached from the city like anything else
-- the player does). So the entry it offered is gone, and with it the resume prompt and the terminal
-- card: there is one company on one save now, every ending walks back into the city, and a second door
-- with its own save semantics is exactly how two paths drift apart.
--
-- Left on disk for the same reason the Quest Board is (models/building.lua's RETIRED): nothing here was
-- wrong, it answered a shape the game no longer has, and deleting it would throw away the resume card
-- and the account-of-a-run card if either is ever wanted again.
--
-- ---------------------------------------------------------------------------
--
-- THE DESCENT: seven circles, dealt in a different order every time, and the Hollow Crown under them.
--
-- A game mode, chosen at the title screen (states/menu.lua), and separate from the campaign in the one
-- way that matters: a run carries nothing in and banks nothing out. It walks in with ONE body, picks up
-- the rest of its company on the road (models/descent_recruit.lua), fights down floor by floor, and when
-- it ends -- the Crown broken, the company wiped, or the player giving up on a floor -- the company and
-- everything it found go with it. Those three are the whole list: a landing used to offer a fourth, an
-- extraction, and it ended a run with nothing to show for it because there is nothing here to show it
-- ON. What a descent is for is the bottom.
--
-- THIS SCREEN USED TO BE THE MUSTER, and deleting it is the point rather than a tidy-up. A run opened on
-- a shelf of eleven candidates and a twelve-coin purse, and bought a company of up to eight before a tile
-- was walked: the whole run settled on a screen, by comparing bodies the player had never fought with,
-- and every run after the first opened on that same screen again. What the mouth of a descent wants is a
-- stair. So the mode now goes straight down, and the choosing happens three times on the way, one floor
-- apart, against a company that exists and a circle already fought.
--
-- WHAT IS LEFT HERE is the two things a run cannot start or finish without: the question asked of a run
-- found on disk, and the account of one that has ended. Both are cards (ui/panels/choice.lua), held in
-- `card` exactly as states/draft.lua holds its own. With neither in play this state has nothing to draw
-- and does not linger: entering with no saved run mints a company and switches straight to floor one.
--
-- WHAT THE MODE IS MADE OF, and how little of it is new:
--
--   the run          models/descent.lua -- the floor stack, the shuffle, the circles, the landing
--   the floors       states/game.lua, unchanged. A floor descriptor is a legal quest (Descent.floorQuest)
--   the company      one body in (Descent.startingCompany), the rest found on the floors
--   levels           earned per body in the fighting (models/experience.lua), since there is no prestige
--   this file        the resume question, the card that says how the run ended, and the way in
--
-- A run in progress persists to Descent.FILE on every beat states/game.lua already saves on, so quitting
-- mid-floor and coming back finds the run waiting -- and ASKS, rather than silently resuming or silently
-- discarding, because a floor is half an hour and neither answer should be assumed.

local State = require("states")
local Choice = require("ui.panels.choice")
local Scale = require("scale")
local Theme = require("ui.theme")
local ScreenFx = require("ui.screen_fx")
local Descent = require("models.descent")
local Player = require("models.player")

local descent = {}

local titleFont = Theme.display(34)
local smallFont = Theme.body(13)

-- ---------------------------------------------------------------------------
-- Going down
-- ---------------------------------------------------------------------------

-- `Player.active` is set because the whole stack below reads it -- Player.save writes it, and the panels
-- a run opens along the way (the party sheet, a merchant) take it. Setting it to a descent's throwaway
-- company is safe precisely because that company carries its own `saveFile` (models/descent.lua): while a
-- run is under way every save in the game writes to the descent's file, and none of them can reach the
-- campaign's. Coming back to the title screen leaves it set to a profile nothing will ask for again.
--
-- A NEW DESCENT OPENS AT THE GATE, WITH NOBODY. The player is a tactician and owns no body on the board
-- (models/descent.lua), so there is nothing to create and nothing to walk in with -- the company is
-- hired at the gate, off the same authored slate the floors offer, and the stair does not open until
-- somebody has been (Gate.canDescend).
--
-- This used to mint a company and switch straight to floor one, past a character-creation screen. Both
-- are gone: there is a town at the mouth now, and hiring is what a town at the mouth is for.
local function beginRun()
    local profile = Descent.newProfile(Descent.startingCompany())
    Player.active = profile
    descent.card = nil
    State.switch(require("states.gate"), { player = profile, run = Descent.new(profile) })
end

-- ---------------------------------------------------------------------------
-- The cards: resume the saved run, and the account of a finished one
-- ---------------------------------------------------------------------------

-- Continue the run on disk, or throw it away and go down again. Neither is assumed: silently resuming
-- hands a player a floor they did not choose today, and silently discarding costs them the floors they
-- already fought. Not closeable -- there is no third answer, and backing out of the question would leave
-- the mode with no screen.
local function promptResume()
    local profile = Descent.loadProfile()
    local run = profile and profile.resumeRun
    if not (run and run.descent) then
        -- Unreadable, or a file with no floor in it. Drop it rather than offering a resume that cannot
        -- happen; walking in fresh is the honest answer.
        Descent.clearSaved()
        beginRun()
        return
    end

    local depth = Descent.depth(run.descent)
    descent.card = Choice.new({
        title = "The company is still down there.",
        prompt = "They are on floor " .. depth .. ", on the ground they had mapped when you left them.",
        options = {
            {
                label = "Go back down",
                desc = "Floor " .. depth .. ", exactly as you left it: the same fog lifted, the same " ..
                    "stops cleared, the same way back up.",
                accent = { 0.83, 0.73, 0.45 },
                cb = function()
                    descent.card = nil
                    -- The resume descriptor carries its own board, token position and floor stack, so
                    -- nothing is rebuilt here. Same shape the campaign's Continue hands states/game.lua.
                    profile.resumeRun = nil
                    Player.active = profile
                    State.switch(require("states.game"), run.quest, nil, profile, nil, run)
                end,
            },
            {
                label = "Leave them and start over",
                desc = "The run below ends where it stands. Somebody else walks in at the gate alone.",
                accent = { 0.42, 0.80, 0.62 },
                cb = function()
                    Descent.clearSaved()
                    beginRun()
                end,
            },
        },
    })
end

-- HOW THE RUN ENDED. The only account of it there is: nothing is banked and there is no hub overlay on
-- the other side, so if a run's floors and its circles are not said here they are not said anywhere.
--
-- THREE ENDINGS AND ONE OF THEM IS A WIN. There used to be a fourth -- an extraction, offered at every
-- landing -- and it read as the sensible answer while banking exactly as much as a wipe did. The mode
-- has one thing it is for now, and the wording holds that line: only the Crown gets a sentence that
-- sounds like an achievement, and the other two say plainly what was left down there.
--
-- `floors` is what the company BEAT and `depth` is where it was standing when it stopped
-- (models/descent.lua's Descent.account). A wipe reads the second: dying on the fourth floor cleared
-- three, and reporting four would be crediting the fight that killed them.
local function showResult(result)
    local floors = result.floors or 0
    local lines = {}
    if result.outcome == "won" then
        lines[#lines + 1] = "Seven circles, and the thing under them. The Hollow Crown is broken."
    elseif result.outcome == "climbed" then
        -- THE ONE ENDING THAT COSTS NOTHING, and the only one after which there is something to come
        -- back to. It reads as an interval rather than a result: the company is above ground, the floor
        -- is still mapped, and the next expedition starts on the stair they climbed out by.
        lines[#lines + 1] = "The company came up from floor " .. math.max(1, result.depth or 1) ..
            " with everything it was carrying."
    elseif result.outcome == "wiped" then
        lines[#lines + 1] = "The company went down on floor " .. math.max(1, result.depth or floors + 1) .. "."
    else
        lines[#lines + 1] = floors > 0
            and ("You gave up on floor " .. math.max(1, result.depth or floors) ..
                 " with " .. floors .. (floors == 1 and " circle behind you." or " circles behind you."))
            or "You walked away from the gate."
    end

    -- The circles beaten, named in the canonical order of the sins rather than by `pairs` -- a run's
    -- account should read the same way twice.
    local beaten = {}
    for _, sin in ipairs(Descent.SINS) do
        local n = (result.circles or {})[sin.vendor]
        if n and n > 0 then beaten[#beaten + 1] = sin.name end
    end
    if #beaten > 0 then
        lines[#lines + 1] = "Circles beaten: " .. table.concat(beaten, ", ") .. "."
    end

    -- WHAT "AGAIN" MEANS depends on whether there is still a company. A wipe, a giving up and the Crown
    -- all destroy one, so going again mints a new body at the gate. Climbing out does not -- the company
    -- is camped above the floor it mapped -- so the same button takes them back down to it.
    local camped = result.outcome == "climbed" and Descent.hasRun()

    descent.card = Choice.new({
        title = result.title or (camped and "Back above ground." or "The run is over."),
        prompt = table.concat(lines, "  "),
        options = {
            {
                label = camped and "Go back down" or "Go down again",
                desc = camped
                    and ("The same company, and floor " .. math.max(1, result.depth or 1) ..
                         " as they left it.")
                    or "One body at the gate again, and the circles dealt in a different order.",
                accent = { 0.83, 0.73, 0.45 },
                cb = function() if camped then promptResume() else beginRun() end end,
            },
            {
                label = "Back to Menu",
                desc = "Leave the descent.",
                accent = { 0.50, 0.68, 0.92 },
                cb = function() State.switch(require("states.menu")) end,
            },
        },
    })
end

-- ---------------------------------------------------------------------------
-- State callbacks
-- ---------------------------------------------------------------------------

-- `opts.result` is handed back by states/game.lua when a run ends (Descent.account, plus the outcome).
-- Without one this is a fresh entry from the title screen, which goes straight down.
function descent.enter(self, opts)
    opts = opts or {}
    ScreenFx.reset() -- a lost fight leaves the world grey; the gate opens on full colour
    require("models.sound").music("music.menu")
    descent.card = nil

    if opts.result then
        -- The run is already over and its file already cleared by the caller; nothing here may resume it.
        showResult(opts.result)
    elseif Descent.hasRun() then
        promptResume()
    else
        -- Straight to floor one. Switching states from inside `enter` is safe: State.switch has already
        -- seated this state before calling us, and the game state simply takes its place.
        beginRun()
    end
end

function descent.update(dt)
    if descent.card and descent.card.update then descent.card:update(dt) end
end

-- The gate behind whichever card is open. There is no screen of its own any more -- a card is always the
-- reason this state is on top -- so this is a backdrop and a name, not a layout.
function descent.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Descent", 0, 54, Scale.WIDTH, "center")
    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf("No target and no contract. Seven circles, and the thing under them.",
        0, 100, Scale.WIDTH, "center")

    if descent.card then descent.card:draw() end
end

local function toMenu() State.switch(require("states.menu")) end

function descent.mousemoved(x, y)
    if descent.card then return descent.card:mousemoved(x, y) end
end

function descent:cursorKind(x, y)
    if descent.card then return descent.card.cursorKind and descent.card:cursorKind(x, y) or "arrow" end
    return "arrow"
end

function descent.mousepressed(x, y, button)
    if descent.card then return descent.card:mousepressed(x, y, button) end
end

function descent.wheelmoved(dx, dy)
    if descent.card and descent.card.wheelmoved then descent.card:wheelmoved(dx, dy) end
end

function descent.keypressed(key)
    if descent.card then return descent.card:keypressed(key) end
    if key == "escape" then return toMenu() end
end

function descent.gamepadpressed(joystick, button)
    if descent.card then return descent.card:gamepadpressed(joystick, button) end
    if button == "b" then return toMenu() end
end

return descent
