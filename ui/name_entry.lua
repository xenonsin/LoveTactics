-- Name-entry widget: a text field plus an on-screen keyboard, so the Colosseum announcer can ask
-- the created avatar's name and the player can answer with any of the three inputs (the project
-- standard -- mouse + keyboard + gamepad):
--   * physical keyboard types straight into the field (love.textinput), Backspace deletes, Enter submits;
--   * mouse clicks the on-screen keys;
--   * gamepad moves the highlight over the keys (d-pad / stick) and presses A, with B as Backspace
--     and Start to submit.
-- Letters are auto-cased (first upper, the rest lower) so every method yields a tidy name like
-- "Rowan" rather than "ROWAN". Construct with an onSubmit(name) callback:
--
--   local entry = NameEntry.new({ prompt = "...", onSubmit = function(name) ... end })
--
-- Lazy fonts (newed in :new, never at require-time) keep it load-safe. Draw/position everything in
-- the logical 1280x720 space (see scale.lua).

local Scale = require("scale")
local InputMode = require("input_mode")
local ButtonPrompt = require("ui.button_prompt")
local Theme = require("ui.theme")

local NameEntry = {}
NameEntry.__index = NameEntry

-- The on-screen keyboard, row by row. Letter rows are seven wide; the last row holds the three
-- actions. Every cell is one navigable key.
local ROWS = {
    { "A", "B", "C", "D", "E", "F", "G" },
    { "H", "I", "J", "K", "L", "M", "N" },
    { "O", "P", "Q", "R", "S", "T", "U" },
    { "V", "W", "X", "Y", "Z", "-", "'" },
    { "Space", "Back", "Done" },
}

local MAX_LEN = 14
local KEY_W, KEY_H, KEY_GAP = 84, 56, 10

-- The prompt is this screen's TITLE, and in character creation it is the second of two screens that
-- each have one: step 1 draws "A New Journey" at 150 in Theme.display(40)/accentAmber. The block used
-- to be centred on the window instead, which put the prompt at 84 -- so the heading jumped 66px up
-- and shrank a size between the picture and the name, in one flow. Both numbers here are that title's
-- (states/character_creation.lua); the field and keyboard hang off it rather than off the centre.
local TITLE_Y = 150
local TITLE_TO_FIELD = 60   -- title top to field top
local FIELD_TO_KEYS = 96    -- field top to the first key row

function NameEntry.new(opts)
    opts = opts or {}
    local self = setmetatable({}, NameEntry)
    self.prompt = opts.prompt or "What is your name?"
    self.onSubmit = opts.onSubmit
    self.text = ""
    self.row, self.col = 1, 1

    self.titleFont = Theme.display(40)
    self.fieldFont = Theme.display(34)
    self.keyFont = Theme.body(22)

    self.axisActive = false
    self:layout()
    return self
end

-- Compute each key's rect, the block centered horizontally and hanging off the title (TITLE_Y).
function NameEntry:layout()
    self.titleY = TITLE_Y
    self.fieldY = self.titleY + TITLE_TO_FIELD
    local startY = self.fieldY + FIELD_TO_KEYS
    self.keys = {}
    for r, row in ipairs(ROWS) do
        local rowW = #row * KEY_W + (#row - 1) * KEY_GAP
        -- The action row's three wide keys read better a touch larger; keep the same cell math but
        -- center whatever this row's width is, so short rows still sit under the letters.
        local startX = Scale.WIDTH / 2 - rowW / 2
        local y = startY + (r - 1) * (KEY_H + KEY_GAP)
        for c, label in ipairs(row) do
            self.keys[#self.keys + 1] = {
                r = r, c = c, label = label,
                x = startX + (c - 1) * (KEY_W + KEY_GAP),
                y = y, w = KEY_W, h = KEY_H,
            }
        end
    end
end

function NameEntry:keyAt(r, c)
    for _, k in ipairs(self.keys) do
        if k.r == r and k.c == c then return k end
    end
    return nil
end

-- Append a character, auto-casing letters (first upper, rest lower) so the name is tidy no matter
-- which input typed it. Space/punctuation append as-is. Silently ignores input past the length cap.
function NameEntry:addChar(ch)
    if #self.text >= MAX_LEN then return end
    if ch:match("%a") then
        ch = (#self.text == 0) and ch:upper() or ch:lower()
    end
    self.text = self.text .. ch
end

function NameEntry:backspace()
    self.text = self.text:sub(1, -2)
end

function NameEntry:submit()
    if #self.text == 0 then return end -- a name is required; Done/Enter do nothing while empty
    if self.onSubmit then self.onSubmit(self.text) end
end

-- Act on a key by its label: the three actions, or a literal character.
function NameEntry:pressLabel(label)
    if label == "Space" then
        self:addChar(" ")
    elseif label == "Back" then
        self:backspace()
    elseif label == "Done" then
        self:submit()
    else
        self:addChar(label)
    end
end

-- Move the on-screen highlight, clamping to each row's real width (rows differ in length).
function NameEntry:move(dr, dc)
    self.row = math.max(1, math.min(#ROWS, self.row + dr))
    self.col = math.max(1, math.min(#ROWS[self.row], self.col + dc))
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function NameEntry:textinput(t)
    -- Only letters, spaces, hyphen, apostrophe -- the same alphabet the on-screen keyboard offers.
    if t:match("^[%a%-' ]$") then self:addChar(t) end
end

function NameEntry:keypressed(key)
    if key == "backspace" then
        self:backspace()
    elseif key == "return" or key == "kpenter" then
        self:submit()
    elseif key == "up" then
        self:move(-1, 0)
    elseif key == "down" then
        self:move(1, 0)
    elseif key == "left" then
        self:move(0, -1)
    elseif key == "right" then
        self:move(0, 1)
    elseif key == "space" then
        self:addChar(" ")
    end
    -- Note: letter keys arrive via textinput, not keypressed, so they are not handled here.
end

function NameEntry:update(dt)
    -- Analog stick navigation with edge detection, matching ui/menu.lua's feel.
    local moved = false
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            local x, y = joystick:getGamepadAxis("leftx"), joystick:getGamepadAxis("lefty")
            if not self.axisActive then
                if y <= -0.5 then self:move(-1, 0); moved = true
                elseif y >= 0.5 then self:move(1, 0); moved = true
                elseif x <= -0.5 then self:move(0, -1); moved = true
                elseif x >= 0.5 then self:move(0, 1); moved = true end
            elseif math.abs(x) >= 0.5 or math.abs(y) >= 0.5 then
                moved = true
            end
        end
    end
    self.axisActive = moved
end

function NameEntry:gamepadpressed(joystick, button)
    if button == "dpup" then self:move(-1, 0)
    elseif button == "dpdown" then self:move(1, 0)
    elseif button == "dpleft" then self:move(0, -1)
    elseif button == "dpright" then self:move(0, 1)
    elseif button == "a" then
        local k = self:keyAt(self.row, self.col)
        if k then self:pressLabel(k.label) end
    elseif button == "b" then
        self:backspace()
    elseif button == "start" then
        self:submit()
    end
end

function NameEntry:mousemoved(x, y)
    for _, k in ipairs(self.keys) do
        if x >= k.x and x <= k.x + k.w and y >= k.y and y <= k.y + k.h then
            self.row, self.col = k.r, k.c
            return
        end
    end
end

function NameEntry:mousepressed(x, y, button)
    if button ~= 1 then return end
    for _, k in ipairs(self.keys) do
        if x >= k.x and x <= k.x + k.w and y >= k.y and y <= k.y + k.h then
            self.row, self.col = k.r, k.c
            self:pressLabel(k.label)
            return
        end
    end
end

function NameEntry:cursorKind(x, y)
    for _, k in ipairs(self.keys) do
        if x >= k.x and x <= k.x + k.w and y >= k.y and y <= k.y + k.h then return "hand" end
    end
    return "arrow"
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function NameEntry:draw()
    -- The SAME ground every other screen stands on (Theme.drawMount), and it used to be a hand-mixed
    -- navy laid down right here. Character creation runs this widget as its second step, straight off
    -- a first step drawn on the mount, so the two halves of one flow changed colour underneath the
    -- player between the picture and the name.
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    -- The prompt, in the title's own place and register (see TITLE_Y).
    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.prompt, 0, self.titleY, Scale.WIDTH, "center")

    -- The text field: a wide box with the typed name and a blinking caret.
    local fw, fh = 520, 60
    local fx = Scale.WIDTH / 2 - fw / 2
    love.graphics.setColor(0.08, 0.09, 0.13)
    love.graphics.rectangle("fill", fx, self.fieldY, fw, fh, 8, 8)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", fx, self.fieldY, fw, fh, 8, 8)
    love.graphics.setFont(self.fieldFont)
    love.graphics.setColor(0.95, 0.95, 0.98)
    local caret = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "|" or ""
    love.graphics.printf(self.text .. caret, fx + 12, self.fieldY + fh / 2 - 20, fw - 24, "center")

    -- The on-screen keyboard.
    love.graphics.setFont(self.keyFont)
    for _, k in ipairs(self.keys) do
        local active = (k.r == self.row and k.c == self.col)
        love.graphics.setColor(active and 0.35 or 0.20, active and 0.40 or 0.23, active and 0.55 or 0.32)
        love.graphics.rectangle("fill", k.x, k.y, k.w, k.h, 6, 6)
        love.graphics.setColor(active and 0.95 or 0.5, active and 0.85 or 0.55, active and 0.55 or 0.7)
        love.graphics.rectangle("line", k.x, k.y, k.w, k.h, 6, 6)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.printf(k.label, k.x, k.y + k.h / 2 - 12, k.w, "center")
    end

    -- Control hints.
    local segs = InputMode.isGamepad()
        and { { glyph = "A", label = "Press" }, { glyph = "B", label = "Back" }, { glyph = "Start", label = "Done" } }
        or { { glyph = "Type", label = "Name" }, { glyph = "Enter", label = "Done" } }
    ButtonPrompt.draw(segs, 0, Scale.HEIGHT - 40, Scale.WIDTH - 40, { align = "right" })

    love.graphics.setColor(1, 1, 1)
end

return NameEntry
