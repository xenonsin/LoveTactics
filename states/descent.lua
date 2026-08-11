-- THE DESCENT: seven circles, dealt in a different order every time, and the Hollow Crown under them.
--
-- A game mode, chosen at the title screen (states/menu.lua), and separate from the campaign in the one
-- way that matters: a run carries nothing in and banks nothing out. It musters its own company off a
-- shelf at the mouth (models/descent_muster.lua), fights down floor by floor, and when it ends -- climbed
-- out, wiped, or walked away from -- the company and everything it found go with it.
--
-- This card spent a while as a pop-up on the city's first building, "The Gate", with the campaign's quest
-- board demoted to a child panel of it, and it banked into the campaign save: standing per house, a
-- deepest-floor record, a prestige point per floor of new record. That made the descent the campaign's
-- progression engine rather than a mode. Pulling it out here cost the campaign nothing -- its levels come
-- from Quest.PRESTIGE_PER_QUEST and its shelves from finished quests, neither of which the descent fed --
-- and it gave the city back its board.
--
-- WHAT THE MODE IS MADE OF, and how little of it is new:
--
--   the run          models/descent.lua -- the floor stack, the shuffle, the circles, the landing
--   the floors       states/game.lua, unchanged. A floor descriptor is a legal quest (Descent.floorQuest)
--   the company      a player-shaped profile with its own save file (Descent.newProfile)
--   levels           earned per body in the fighting (models/experience.lua), since there is no prestige
--   this file        the muster, the resume question, and the card that says how the run ended
--
-- Three screens, one at a time, held in `card` exactly as states/draft.lua holds its own. A run in
-- progress persists to Descent.FILE on every beat states/game.lua already saves on, so quitting mid-floor
-- and coming back finds the run waiting -- and ASKS, rather than silently resuming or silently discarding,
-- because a floor is half an hour and neither answer should be assumed.

local State = require("states")
local Menu = require("ui.menu")
local Choice = require("ui.panels.choice")
local CloseButton = require("ui.close_button")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")
local ScreenFx = require("ui.screen_fx")
local Character = require("models.character")
local Descent = require("models.descent")
local Item = require("models.item")
local Muster = require("models.descent_muster")
local Player = require("models.player")

local descent = {}

local titleFont = Theme.display(34)
local headFont = Theme.display(20)
local bodyFont = Theme.body(16)
local smallFont = Theme.body(13)

-- The muster's two columns, in the 1280x720 logical space: the shelf on the left, the body it is
-- pointing at on the right.
-- Sized so the WHOLE shelf plus the Descend row below it fits without scrolling: a muster is a
-- comparison between bodies, and a list that scrolls asks the player to hold half of it in their head --
-- it also pushed the one button that starts the run below the fold. Muster.SHELF_SIZE is picked against
-- these numbers, so the two move together.
local LIST_X, LIST_W = 90, 420
local LIST_TOP, ROW_H, ROW_GAP = 178, 32, 5
local DETAIL_X, DETAIL_W = 560, 630

-- Muster state, rebuilt by openMuster. `picks` is the company so far, as ids in the order taken.
local shelf, picks, menu, closeButton

local function printWrapped(text, font, x, y, w)
    love.graphics.setFont(font)
    local _, lines = font:getWrap(text, w)
    love.graphics.printf(text, x, y, w, "left")
    return #lines * font:getHeight()
end

local function isPicked(id)
    for _, taken in ipairs(picks) do
        if taken == id then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- The muster
-- ---------------------------------------------------------------------------

local buildMenu, beginRun

-- Take a body, or put it back. Both directions, because a muster the player cannot undo is a muster they
-- have to get right first time with no way to compare -- and comparing is the whole of the decision.
--
-- A refusal SAYS SO (descent.message, drawn under the shelf). A click that silently does nothing reads as
-- a broken button, and the two reasons a body can be refused clear differently -- a full company is fixed
-- for the rest of the muster, an empty purse clears the moment something dearer is put back -- so which
-- one it is is worth a line.
local function toggle(id)
    for i, taken in ipairs(picks) do
        if taken == id then
            table.remove(picks, i)
            descent.message = nil
            buildMenu()
            return
        end
    end
    local refusal = Muster.refusal(picks, id)
    if refusal then descent.message = refusal; return end
    descent.message = nil
    picks[#picks + 1] = id
    buildMenu()
end

-- ONE MENU, NOT TWO. The shelf's rows and the Descend row share a widget so there is a single selection
-- to move and a single thing Enter presses -- the alternative is two focus rings and a Tab between them,
-- for one button. The last row is where a full company goes down; short of COMPANY_MIN it says what is
-- missing instead of being greyed out, because a control that will not say why it refuses is worse than
-- one that is not there (a plate that only reads "Descend" and does nothing is the failure this avoids).
function buildMenu()
    local selected = menu and menu.selected or 1
    local items = {}

    for _, id in ipairs(shelf) do
        local def = Character.defs[id]
        items[#items + 1] = {
            label = (def and def.name) or id,
            -- The right-hand column: the price, or the fact that this one is already in the company. Read
            -- at draw time, so taking a body needs no rebuild of the row (see ui/menu.lua on `value`) --
            -- and it is the price rather than a bare marker because what a body costs is the thing the
            -- player is weighing against the purse below.
            value = function()
                return isPicked(id) and "In" or tostring(Muster.costOf(id))
            end,
            action = function() toggle(id) end,
        }
    end

    items[#items + 1] = {
        label = Muster.ready(picks) and ("Descend with " .. #picks .. " ")
            or ("Take " .. (Muster.COMPANY_MIN - #picks) .. " more to fill the board"),
        action = function()
            if Muster.ready(picks) then beginRun() end
        end,
    }

    menu = Menu.new(items, {
        buttonWidth = LIST_W, buttonHeight = ROW_H, spacing = ROW_GAP,
        startY = LIST_TOP, centerX = LIST_X + LIST_W / 2,
        -- Every shelf row plus the Descend row: nothing scrolls, and the button that starts the run is
        -- always on screen. See the layout constants above.
        font = bodyFont, maxVisible = Muster.SHELF_SIZE + 1,
    })
    menu.selected = math.min(selected, #items)
    menu:layout()
end

-- The id the detail column is describing, or nil when the cursor is on the Descend row.
local function selectedId()
    local i = menu and menu.selected
    return i and shelf[i] or nil
end

local function openMuster()
    -- A fresh shelf per visit. The seed is the run's seed in every sense that matters -- a muster is the
    -- first thing a run does -- and it is rolled here rather than carried in because there is no run yet
    -- to carry it: Descent.new mints its own when the company walks in.
    shelf = Muster.shelf(os.time() % 1000000)
    picks = {}
    descent.card = nil
    descent.message = nil
    buildMenu()
end

-- The company is chosen: mint its profile, make it the active player, and open floor one.
--
-- `Player.active` is set because the whole stack below reads it -- Player.save writes it, and the panels
-- a run opens along the way (the party sheet, a merchant) take it. Setting it to a descent's throwaway
-- company is safe precisely because that company carries its own `saveFile` (models/descent.lua): while a
-- run is under way every save in the game writes to the descent's file, and none of them can reach the
-- campaign's. Coming back to the title screen leaves it set to a profile nothing will ask for again.
function beginRun()
    local profile = Descent.newProfile(Muster.company(picks))
    Player.active = profile
    local run = Descent.new(profile)
    State.switch(require("states.game"), Descent.floorQuest(run, profile), 1, profile)
end

-- ---------------------------------------------------------------------------
-- The cards: resume the saved run, and the account of a finished one
-- ---------------------------------------------------------------------------

-- Continue the run on disk, or throw it away and muster a new company. Neither is assumed: silently
-- resuming hands a player a company they did not choose today, and silently discarding costs them the
-- floors they already fought. Not closeable -- there is no third answer, and backing out of the question
-- would leave the mode with no screen.
local function promptResume()
    local profile = Descent.loadProfile()
    local run = profile and profile.resumeRun
    if not (run and run.descent) then
        -- Unreadable, or a file with no floor in it. Drop it rather than offering a resume that cannot
        -- happen; the muster below is the honest answer.
        Descent.clearSaved()
        openMuster()
        return
    end

    local depth = Descent.depth(run.descent)
    descent.card = Choice.new({
        title = "The company is still down there.",
        prompt = "You stopped on floor " .. depth .. ". Nothing was banked when you quit, and nothing " ..
            "was lost either.",
        options = {
            {
                label = "Go back down",
                desc = "Floor " .. depth .. ", exactly as you left it, with everything the company is " ..
                    "carrying still at stake.",
                accent = { 0.83, 0.73, 0.45 },
                cb = function()
                    descent.card = nil
                    -- The resume descriptor carries its own board, token position and floor stack, so
                    -- nothing is rebuilt here. Same shape the campaign's Continue hands states/game.lua.
                    profile.resumeRun = nil
                    Player.active = profile
                    State.switch(require("states.game"), run.quest, run.prestige, profile, nil, run)
                end,
            },
            {
                label = "Leave them and start over",
                desc = "The run below ends where it stands. A new company musters at the gate.",
                accent = { 0.42, 0.80, 0.62 },
                cb = function()
                    Descent.clearSaved()
                    openMuster()
                end,
            },
        },
    })
end

-- HOW THE RUN ENDED. The only account of it there is: nothing is banked and there is no hub overlay on
-- the other side, so if a run's floors and its circles are not said here they are not said anywhere.
local function showResult(result)
    local floors = result.floors or 0
    local lines = {}
    if result.outcome == "extracted" then
        lines[#lines + 1] = floors == 1 and "One floor, and out."
            or ("You climbed out from floor " .. floors .. ".")
    elseif result.outcome == "wiped" then
        lines[#lines + 1] = "The company went down on floor " .. math.max(1, floors) .. "."
    else
        lines[#lines + 1] = floors > 0 and ("You walked out of floor " .. floors .. " and left the gate.")
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

    descent.card = Choice.new({
        title = result.title or "The run is over.",
        prompt = table.concat(lines, "  "),
        options = {
            {
                label = "Muster again",
                desc = "A new shelf, a new company, and the circles dealt in a different order.",
                accent = { 0.83, 0.73, 0.45 },
                cb = function() openMuster() end,
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

-- `opts.result` is handed back by states/game.lua when a run ends (Descent.extract's account, or a wipe).
-- Without one this is a fresh entry from the title screen.
function descent.enter(self, opts)
    opts = opts or {}
    ScreenFx.reset() -- a lost fight leaves the world grey; the gate opens on full colour
    require("models.sound").music("music.menu")

    -- Anchored to the screen's own top-right corner: this is a full screen, not a box inside one, so the
    -- corner the button insets from is the frame (ui/close_button.lua takes the corner, not the button).
    closeButton = CloseButton.new(Scale.WIDTH, 8)
    shelf, picks = {}, {}
    descent.card = nil

    if opts.result then
        -- The run is already over and its file already cleared by the caller; nothing here may resume it.
        showResult(opts.result)
    elseif Descent.hasRun() then
        promptResume()
    else
        openMuster()
    end
end

function descent.update(dt)
    if descent.card then
        if descent.card.update then descent.card:update(dt) end
        return
    end
    if menu then menu:update(dt) end
end

-- The body the cursor is on, read whole: what it is, what it brings, and what it costs. A muster is a
-- decision about bodies, so the column has to say enough about one to choose it over another.
local function drawDetail()
    local id = selectedId()
    local x, y, w = DETAIL_X, LIST_TOP - 8, DETAIL_W

    if not id then
        Theme.set(Theme.muted)
        printWrapped("Eight go down at most, and " .. Muster.COMPANY_MIN .. " stand on the board at " ..
            "once. Everything they find below is theirs only if they climb back out with it.",
            bodyFont, x, y, w)
        return
    end

    local def = Character.defs[id]
    if not def then return end

    Theme.set(Theme.accentAmber)
    local ty = y + printWrapped(def.name or id, headFont, x, y, w) + 4
    Theme.set(Theme.muted)
    ty = ty + printWrapped((def.class or "unclassed") .. "   " .. (def.archetype or "") ..
        "   costs " .. Muster.costOf(id), smallFont, x, ty, w) + 12

    local st = def.stats or {}
    Theme.set(Theme.ink)
    ty = ty + printWrapped(
        "Health " .. (st.health or 0) .. "    Damage " .. (st.damage or 0) ..
        "    Defense " .. (st.defense or 0) .. "    Move " .. (st.movement or 0),
        bodyFont, x, ty, w) + 14

    -- The kit, which is the point: a descent body arrives wearing exactly what its blueprint authors, so
    -- what is listed here is what it will actually be fighting with on floor one.
    Theme.set(Theme.muted)
    ty = ty + printWrapped("Comes carrying", smallFont, x, ty, w) + 4
    Theme.set(Theme.ink)
    for _, itemId in ipairs(def.startingItems or {}) do
        if itemId then
            local idef = Item.defs[itemId]
            ty = ty + printWrapped("- " .. ((idef and idef.name) or itemId), smallFont, x + 8, ty, w - 8) + 1
        end
    end
end

function descent.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Descent", 0, 54, Scale.WIDTH, "center")
    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf("No target and no contract. Seven circles, and the thing under them.",
        0, 100, Scale.WIDTH, "center")

    if menu and not descent.card then
        Theme.set(Theme.muted)
        love.graphics.setFont(smallFont)
        love.graphics.print("The shelf", LIST_X, LIST_TOP - 24)
        -- The two numbers the muster is decided on, side by side above the list they refer to: how many
        -- bodies are in, and what is left to spend. Both stated as a transition against their ceiling
        -- rather than as bare counts, so neither has to be held in the head.
        love.graphics.printf(#picks .. " of " .. Muster.COMPANY_MAX .. " taken    " ..
            Muster.remaining(picks) .. " of " .. Muster.BUDGET .. " left",
            LIST_X, LIST_TOP - 24, LIST_W, "right")
        menu:draw()
        drawDetail()

        -- Why the last take was refused, if it was. Cleared by any take that lands.
        if descent.message then
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.90, 0.55, 0.52)
            love.graphics.printf(descent.message, LIST_X, Scale.HEIGHT - 74, LIST_W, "left")
        end

        Theme.set(Theme.muted)
        love.graphics.setFont(bodyFont)
        local hint = InputMode.isGamepad() and "A: take / put back    B: back to menu"
            or "Click / Enter: take or put back    Click X / Esc: back to menu"
        love.graphics.printf(hint, 0, Scale.HEIGHT - 44, Scale.WIDTH, "center")
        closeButton:draw()
    end

    if descent.card then descent.card:draw() end
end

local function toMenu() State.switch(require("states.menu")) end

function descent.mousemoved(x, y)
    if descent.card then return descent.card:mousemoved(x, y) end
    if menu then menu:mousemoved(x, y) end
    closeButton:mousemoved(x, y)
end

function descent:cursorKind(x, y)
    if descent.card then return descent.card.cursorKind and descent.card:cursorKind(x, y) or "arrow" end
    if closeButton:contains(x, y) then return "hand" end
    return (menu and menu:mouseOverItem(x, y)) and "hand" or "arrow"
end

function descent.mousepressed(x, y, button)
    if descent.card then return descent.card:mousepressed(x, y, button) end
    if closeButton:mousepressed(x, y, button) then toMenu() return end
    if menu then menu:mousepressed(x, y, button) end
end

function descent.wheelmoved(dx, dy)
    if descent.card then
        if descent.card.wheelmoved then descent.card:wheelmoved(dx, dy) end
        return
    end
    if menu and menu.wheelmoved then menu:wheelmoved(dx, dy) end
end

function descent.keypressed(key)
    if descent.card then return descent.card:keypressed(key) end
    if key == "escape" then return toMenu() end
    if menu then menu:keypressed(key) end
end

function descent.gamepadpressed(joystick, button)
    if descent.card then return descent.card:gamepadpressed(joystick, button) end
    if button == "b" then return toMenu() end
    if menu then menu:gamepadpressed(joystick, button) end
end

return descent
