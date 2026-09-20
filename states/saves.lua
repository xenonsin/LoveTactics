-- The load list: every campaign on this install, one card each, newest first.
--
-- A SLOT IS A FILE AND THERE IS NO CEILING ON THEM (models/save.lua's Slots section). So this screen
-- is not a fixed board of three plates to be filled and overwritten -- it is a list that grows, which
-- is why it scrolls and why DELETE is a first-class control here rather than a convenience. A list
-- that can only be added to is a list that eventually cannot be read.
--
-- It is also, for the same reason, LOAD-ONLY. New Game does not come through here: with slots
-- unbounded there is no destination to choose, so the menu takes the first free one (Player.newSlot)
-- and this screen never has to ask a player to pick a victim or confirm an overwrite.
--
--   State.switch(require("states.saves"), previousState)   -- Back/Esc returns there
--
-- Rows are ui/menu.lua's card shape (a name over a muted figure line), which is what gets the screen
-- mouse, keyboard and gamepad without three code paths. The delete control is the one thing the
-- widget does not own: the host draws it into each row's right edge and hit-tests it FIRST, because
-- it sits inside a rect the menu would otherwise read as "load this".

local State = require("states")
local Menu = require("ui.menu")
local Choice = require("ui.panels.choice")
local Glyphs = require("ui.glyphs")
local Player = require("models.player")
local Save = require("models.save")
local Scale = require("scale")
local InputMode = require("input_mode")
local Theme = require("ui.theme")

local saves = {}

local titleFont = Theme.display(40)
local bodyFont = Theme.body(16)
local rowFont = Theme.display(20)
local subFont = Theme.body(14)

local TITLE_Y = 84
local ROW_W, ROW_H, ROW_SPACING = 640, 58, 10
local LIST_TOP = 156
local HINT_Y = Scale.HEIGHT - 40

-- The delete control, inset from a row's right edge. Sized well above the 44px-ish a finger needs at
-- this scale is not possible inside a 58px row, so the HIT box is grown past the drawn mark (PAD on
-- every side) -- the glyph is 18px because that is what reads, the target is 34px because that is
-- what can be pressed.
local BIN, BIN_PAD, BIN_INSET = 18, 8, 16

-- The band the "no saved games" line takes when the list is empty, which the lone Back row steps
-- down by so the two do not print over each other.
local EMPTY_H = 48

local widget
local entries = {}  -- Save.slots(), index-aligned with the widget's save rows
local panel         -- the delete confirmation, while one is open

local function backToPrevious()
    State.switch(saves.previous or require("states.menu"))
end

-- WHERE A LOADED SAVE ACTUALLY GOES, and the reason this is a function on this module rather than a
-- few lines in the row's action: the main menu's Continue lands a player exactly the same way, and
-- two copies of "does this save have a run open" is how a resumed descent ends up working from one
-- door and not the other.
--
-- A save made mid-expedition carries a resumable overworld run (models/save.lua), so the player is put
-- back on the map they quit rather than home in the city. Consumed once -- cleared as it is read -- so
-- a bounce back to the menu does not re-resume a stale descriptor.
function saves.load(file)
    -- REFUSE RATHER THAN REPLACE. Player.start falls back to a fresh player when a file will not
    -- restore, which is right for "there is no save here" and catastrophic for "there is one and this
    -- build cannot read it" -- the fresh player is stamped with that slot and overwrites it on its
    -- first write. Save.slots already drops such a file so no row offers it; this is the second lock,
    -- because the cost of the two disagreeing is someone's campaign.
    if not Save.loadable(Save.peek(file)) then return end
    Player.start(false, file)
    local run = Player.active and Player.active.resumeRun
    if run then
        Player.active.resumeRun = nil
        State.switch(require("states.game"), run.quest, nil, Player.active, nil, run)
    else
        State.switch(require("states.hub"))
    end
end

-- A row's delete control, as `drawX, drawY, hitX, hitY, hitSize` -- the mark's own box first, then
-- the larger box that catches the press. Nil for a row with no save behind it (Back), which is what
-- `item.entry` marks.
--
-- The two boxes differ because 18px is what READS at this size and 34px is what can be hit; growing
-- the glyph to the size of its target would put a bin on the row loud enough to compete with the
-- company's name, on a screen where the name is the thing being chosen between.
local function binRect(item)
    if not item or not item.x or not item.entry then return nil end
    local cx = item.x + item.w - BIN_INSET - BIN / 2
    local cy = item.y + item.h / 2
    return cx - BIN / 2, cy - BIN / 2, cx - BIN / 2 - BIN_PAD, cy - BIN / 2 - BIN_PAD, BIN + BIN_PAD * 2
end

local function overBin(px, py)
    if not widget then return nil end
    for _, item in ipairs(widget.items) do
        local _, _, hx, hy, hs = binRect(item)
        if hx and px >= hx and px <= hx + hs and py >= hy and py <= hy + hs then
            return item
        end
    end
    return nil
end

local buildList -- forward: the confirm's callback rebuilds the list it was opened from

-- Ask before destroying. The one irreversible act in the game outside of a fight, so it is confirmed,
-- and the confirmation NAMES THE SAVE -- a bare "are you sure?" on a list of similarly-titled
-- companies is a prompt that cannot be answered correctly.
--
-- Destructive option first would put it under the opening highlight; Keep leads instead, so the
-- default press is the safe one.
local function confirmDelete(entry)
    local title, sub = Save.describe(entry)
    panel = Choice.new({
        title = "Delete this save?",
        prompt = title .. "\n" .. sub,
        options = {
            { label = "Keep", desc = "Leave it where it is.", cb = function() panel = nil end },
            {
                label = "Delete",
                desc = "Erased from this device. It cannot be brought back.",
                accent = { 0.84, 0.36, 0.34 },
                cb = function()
                    Save.clear(entry.file)
                    panel = nil
                    buildList()
                end,
            },
        },
        onClose = function() panel = nil end,
    })
end

-- Rebuilt rather than patched after a delete: the list is derived from the folder, and re-reading it
-- is both cheap enough at this size and the only version that cannot disagree with what is on disk.
buildList = function()
    -- Where the highlight was standing, so a delete does not throw the player back to the top of a
    -- list they were half way down. The row it was on is the row that just went, so the index is kept
    -- and clamped rather than the entry being hunted for -- which lands the cursor on whatever moved
    -- up into the gap, the way a list is expected to behave.
    local was = widget and widget.selected

    entries = Save.slots()

    local items = {}
    for _, entry in ipairs(entries) do
        local title, sub = Save.describe(entry)
        items[#items + 1] = {
            label = title,
            sub = sub,
            entry = entry, -- what marks this as a deletable row; the Back row below carries none
            action = function() saves.load(entry.file) end,
        }
    end

    -- Back is a ROW as well as a key. Esc and B both leave, but the project's standard is that the
    -- game is playable with a mouse alone, and a mouse has no Esc.
    items[#items + 1] = { label = "Back", action = backToPrevious }

    -- How many rows fit above the hint line. Floored at two so a squeezed screen still shows a save
    -- and the way out of the screen, rather than a caret.
    local pitch = ROW_H + ROW_SPACING
    local maxVisible = math.max(2, math.floor(((HINT_Y - 24 - LIST_TOP) + ROW_SPACING) / pitch))

    widget = Menu.new(items, {
        buttonWidth = ROW_W,
        buttonHeight = ROW_H,
        spacing = ROW_SPACING,
        -- An empty list is one Back row, and the "no saved games" line has to go somewhere. It takes
        -- the top of the list and the row steps down for it, rather than the line being tucked up
        -- under the title where it would read as a subtitle of the screen instead of its contents.
        startY = LIST_TOP + ((#entries == 0) and EMPTY_H or 0),
        maxVisible = maxVisible,
        font = rowFont,
        subFont = subFont,
    })

    if was then
        widget.selected = math.max(1, math.min(#items, was))
        widget:scrollToSelection()
    end
end

function saves.enter(self, previous)
    -- Note the `self` first parameter: State.switch calls `state.enter(state, ...)`, so the state's
    -- own table arrives ahead of the caller's arguments. Written as `enter(previous)` this screen
    -- would take ITSELF as the previous state -- the bug states/settings.lua's header records.
    saves.previous = previous
    panel = nil
    buildList()
end

function saves.update(dt)
    -- The list does NOT get update() while the confirmation is up. Menu:update polls the analog
    -- stick, so a pad nudged during the "delete this?" question would walk the highlight around
    -- behind the modal. The answer is still correct either way -- confirmDelete captures the ENTRY,
    -- not the row index, so what gets deleted cannot drift -- but a list visibly moving under a
    -- question about one of its rows says the question is about whatever is lit, and it is not.
    --
    -- It still needs layout(), because the rows and their bins are drawn under the panel: the same
    -- split states/menu.lua makes for its unfocused column.
    if panel then return widget:layout() end
    widget:update(dt)
end

function saves.draw()
    -- Fill the logical area explicitly: letterbox bars are cleared to black, so setBackgroundColor
    -- (which paints the whole real window) cannot be used. Mirrors states/menu.lua.
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Load Game", 0, TITLE_Y, Scale.WIDTH, "center")

    widget:draw()

    -- The bins, over the plates the widget just drew. The plate colour is handed in so the slots are
    -- punched as holes rather than shaded (ui/glyphs.lua's bin) -- and it is the SELECTED plate's
    -- colour on the highlighted row, or the mark's own cutouts would show the wrong ground.
    local selected = widget.items[widget.selected]
    for _, item in ipairs(widget.items) do
        local gx, gy = binRect(item)
        if gx then
            local active = (item == selected) and widget.focused
            local plate = active and Theme.panel or Theme.panel2
            local hot = active and Theme.accentAmber or Theme.muted
            Glyphs.bin(gx, gy, BIN, BIN, hot[1], hot[2], hot[3], active and 1 or 0.55,
                plate[1], plate[2], plate[3])
        end
    end

    love.graphics.setFont(bodyFont)
    Theme.set(Theme.muted)
    if #entries == 0 then
        -- The screen is normally unreachable with nothing on it (the menu hides Load Game), so this is
        -- what the player sees after deleting the last save -- standing on the screen that just
        -- emptied. It says so rather than leaving a lone Back row to be read as a failure.
        love.graphics.printf("No saved games on this device.", 0, LIST_TOP + 12, Scale.WIDTH, "center")
    end

    -- The delete control is named only while there is something to delete, and named for the device
    -- in hand. The mouse needs no line: the bin is on the row.
    local hint
    if InputMode.isGamepad() then
        hint = #entries > 0 and "D-pad: move    A: load    X: delete    B: back"
            or "D-pad: move    A: select    B: back"
    else
        hint = #entries > 0 and "Arrows: move    Enter: load    Del: delete    Esc: back"
            or "Arrows: move    Enter: select    Esc: back"
    end
    love.graphics.printf(hint, 0, HINT_Y, Scale.WIDTH, "center")
    love.graphics.setColor(1, 1, 1)

    if panel then panel:draw() end
end

function saves.mousemoved(x, y)
    if panel then return panel:mousemoved(x, y) end
    widget:mousemoved(x, y)
end

-- Hand over a row or a bin, arrow elsewhere (see ui/cursor.lua).
function saves:cursorKind(x, y)
    if panel then return panel:cursorKind(x, y) end
    if overBin(x, y) then return "hand" end
    return widget:mouseOverItem(x, y) and "hand" or "arrow"
end

function saves.mousepressed(x, y, button)
    if panel then return panel:mousepressed(x, y, button) end
    -- THE BIN IS TESTED FIRST, because it sits inside a rect the menu reads as "load this save". A
    -- click that hits it is spent here and never reaches the widget.
    if button == 1 then
        local item = overBin(x, y)
        if item then return confirmDelete(item.entry) end
    end
    widget:mousepressed(x, y, button)
end

function saves.wheelmoved(dx, dy)
    if panel then return end
    widget:wheelmoved(dx, dy)
end

-- Delete on the HIGHLIGHTED row, which is the row the mouse last hovered as well as the one the
-- arrows walked to (ui/menu.lua keeps the two in sync), so all three inputs delete the same thing.
local function deleteSelected()
    local item = widget.items[widget.selected]
    if item and item.entry then confirmDelete(item.entry) end
end

function saves.keypressed(key)
    if panel then return panel:keypressed(key) end
    if key == "escape" then return backToPrevious() end
    if key == "delete" then return deleteSelected() end
    widget:keypressed(key)
end

function saves.gamepadpressed(joystick, button)
    if panel then return panel:gamepadpressed(joystick, button) end
    if button == "b" then return backToPrevious() end
    if button == "x" then return deleteSelected() end
    widget:gamepadpressed(joystick, button)
end

return saves
