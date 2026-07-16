-- Visual-novel conversation overlay (Fire Emblem / FFT style): a persistent cast of large,
-- bottom-anchored portraits spread across the screen, a scene title top-left, and a text box
-- along the bottom. Each script node makes one cast member the active speaker -- drawn in full
-- colour with a name plate -- while the rest are greyed out. Supports a typewriter reveal and
-- branching player choices (three-input: mouse + keyboard + gamepad).
--
-- Driven globally, not as a state's activePanel: models/conversation.lua holds the live
-- instance and main.lua routes input/update/draw to it, freezing the state behind it. So this
-- widget only needs the widget callbacks -- it never touches State.
--
--   local dlg = Dialogue.new(conversationDef, function() ...scene over... end)
--   dlg:update(dt); dlg:draw()
--   dlg:mousemoved(x, y); dlg:mousepressed(x, y, button)
--   dlg:keypressed(key); dlg:gamepadpressed(joystick, button)
--
-- Lazy fonts (newed in :new, never at require-time) keep it load-safe under tests/ui_load_spec.

local Scale = require("scale")
local InputMode = require("input_mode")
local Sprite = require("models.sprite")
local Conversation = require("models.conversation")
local Locale = require("models.locale")
local ButtonPrompt = require("ui.button_prompt")
local utf8 = require("utf8") -- the typewriter reveals whole CHARACTERS, not bytes (CJK is multibyte)

local Dialogue = {}
Dialogue.__index = Dialogue

-- Fonts must cover whatever the current language needs -- the default LOVE font has no CJK glyphs,
-- so Japanese would render as tofu. Drop a Unicode TTF at assets/fonts/ui.ttf (e.g. Noto Sans JP,
-- which also covers Latin) and it is used for every dialogue font; without it we fall back to the
-- built-in font (fine for English). Lazy: only called from :new (never at require-time).
local function uiFont(size)
    if love.filesystem.getInfo("assets/fonts/ui.ttf") then
        return love.graphics.newFont("assets/fonts/ui.ttf", size)
    end
    return love.graphics.newFont(size)
end

-- Text box geometry (a wide bar along the bottom), and how tall a portrait stands.
local BOX_MARGIN = 60
local BOX_H = 150
local BOX_BOTTOM_GAP = 24
local PORTRAIT_H = 470 -- target portrait height; scaled down to fit its slot width if needed
local REVEAL_CPS = 45  -- typewriter speed, characters per second

-- Greyed (inactive) portrait tint and its letter-box fallback fill; active is full colour.
local INACTIVE_TINT = { 0.34, 0.35, 0.42 }
local ACTIVE_TINT = { 1, 1, 1 }
local FALLBACK_ACTIVE = { 0.42, 0.45, 0.56 }
local FALLBACK_INACTIVE = { 0.20, 0.21, 0.27 }

-- A cast entry is either an id string ("knight") or a table ({ id = "knight", name = ..., slot = ..
-- }); a script node is authored positionally as { "<speaker>", "<text>", id = .., goto = .., choices
-- = { { "<text>", goto = .. }, .. } }. These normalize either shape to a table with `by`/`text`.
local function castEntry(raw)
    return type(raw) == "table" and raw or { id = raw }
end

function Dialogue.new(def, onComplete, convId)
    local self = setmetatable({}, Dialogue)
    self.convId = convId
    self.onComplete = onComplete
    self.done = false
    -- Title is authored inline (English) and localized under the stable id "title.<conv>".
    self.title = def.title and Locale.get(Locale.key.title(convId), def.title) or nil

    self.titleFont = uiFont(22)
    self.nameFont = uiFont(20)
    self.textFont = uiFont(22)
    self.choiceFont = uiFont(19)
    self.fallbackFont = uiFont(64)

    -- Box rect, spanning the width along the bottom.
    self.boxX = BOX_MARGIN
    self.boxW = Scale.WIDTH - BOX_MARGIN * 2
    self.boxH = BOX_H
    self.boxY = Scale.HEIGHT - BOX_H - BOX_BOTTOM_GAP

    -- Normalize the positional script into { by, text, id, goto, name, portrait, choices } nodes so
    -- the rest of the widget reads named fields regardless of how the scene was authored.
    self.script = {}
    for i, raw in ipairs(def.script or {}) do
        local node = {
            by = raw.by or raw[1],
            text = raw.text or raw[2] or "",
            tag = raw.tag,         -- stable localization id, stamped by tools/extract_strings.lua
            id = raw.id,
            goto = raw.goto,
            name = raw.name,       -- ad-hoc speaker name (a narrator not in the cast)
            portrait = raw.portrait,
        }
        if raw.choices then
            node.choices = {}
            for j, c in ipairs(raw.choices) do
                node.choices[j] = { text = c.text or c[1] or "", tag = c.tag, goto = c.goto }
            end
        end
        self.script[i] = node
    end

    -- Resolve the persistent cast once: name + loaded portrait image, positioned at evenly
    -- spaced slots across the width (or an explicit `slot`). `image` is a love.Image when the
    -- art exists, else the path string (Sprite.load is tolerant) -> the letter-box fallback.
    self.cast = {}
    self.castById = {}
    local entries = def.cast or {}
    local n = #entries
    for i, raw in ipairs(entries) do
        local entry = castEntry(raw)
        local who = Conversation.speaker(entry.id, entry)
        local slot = entry.slot or i
        local member = {
            id = entry.id,
            name = who.name,
            image = Sprite.load(who.portrait),
            centerX = Scale.WIDTH * slot / (n + 1),
        }
        self.cast[i] = member
        self.castById[entry.id] = member
    end

    self.index = 1
    self:startNode()
    return self
end

-- An entry's (a node's or a choice's) display text. The author writes only inline English; the
-- extraction tool stamps a stable `tag`, and translations live under "line.<conv>.<tag>". At runtime
-- the current language's translation (keyed by that id) is used, falling back to the inline English.
function Dialogue:textOf(entry)
    if not entry then return "" end
    if entry.tag ~= nil then
        return Locale.get(Locale.key.line(self.convId, entry.tag), entry.text or "")
    end
    return entry.text or ""
end

-- Begin (or restart) the current node: reset the typewriter and any choice selection.
function Dialogue:startNode()
    local node = self.script[self.index]
    self.reveal = 0
    self.revealDone = false
    self.fullText = self:textOf(node)
    self.textLen = utf8.len(self.fullText) or #self.fullText -- length in characters, for the reveal
    self.choiceSel = 1
    -- Precompute choice option rects for mouse hit-testing (built in draw when first shown).
    self.choiceRects = nil
end

function Dialogue:currentNode()
    return self.script[self.index]
end

-- Whether the current node is waiting on a player choice (only once the line has fully revealed).
function Dialogue:choicesActive()
    local node = self:currentNode()
    return self.revealDone and node and node.choices ~= nil
end

-- Move to the next node (following `gotoLabel`), or finish the scene when there is none.
function Dialogue:advance(gotoLabel)
    local nextIdx = Conversation.nextIndex(self.script, self.index, gotoLabel)
    if nextIdx then
        self.index = nextIdx
        self:startNode()
    else
        self:finish()
    end
end

function Dialogue:finish()
    if self.done then return end
    self.done = true
    if self.onComplete then self.onComplete() end
end

-- The one "advance / confirm" gesture, shared by Enter/Space, gamepad A/Start, and a box click:
--   * mid-reveal      -> snap the typewriter to the full line (let the reader catch up)
--   * awaiting choice -> commit the highlighted choice (jump to its `goto`)
--   * otherwise       -> advance past this node (following the node's own `goto`)
function Dialogue:confirm()
    if not self.revealDone then
        self.reveal = self.textLen
        self.revealDone = true
        return
    end
    local node = self:currentNode()
    if node and node.choices then
        local choice = node.choices[self.choiceSel]
        self:advance(choice and choice.goto)
        return
    end
    self:advance(node and node.goto)
end

function Dialogue:moveChoice(delta)
    local node = self:currentNode()
    if not (self:choicesActive() and node.choices) then return end
    local count = #node.choices
    self.choiceSel = (self.choiceSel - 1 + delta) % count + 1
end

function Dialogue:update(dt)
    if not self.revealDone then
        self.reveal = self.reveal + dt * REVEAL_CPS
        if self.reveal >= self.textLen then
            self.reveal = self.textLen
            self.revealDone = true
        end
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function Dialogue:keypressed(key)
    if key == "escape" then
        self:finish()
    elseif key == "up" or key == "w" then
        self:moveChoice(-1)
    elseif key == "down" or key == "s" then
        self:moveChoice(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:confirm()
    end
end

function Dialogue:gamepadpressed(joystick, button)
    if button == "b" then
        self:finish()
    elseif button == "dpup" then
        self:moveChoice(-1)
    elseif button == "dpdown" then
        self:moveChoice(1)
    elseif button == "a" or button == "start" then
        self:confirm()
    end
end

function Dialogue:mousemoved(x, y)
    -- Hover a choice option to highlight it, so mouse and keyboard stay in sync.
    if self:choicesActive() and self.choiceRects then
        for i, r in ipairs(self.choiceRects) do
            if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
                self.choiceSel = i
                break
            end
        end
    end
end

function Dialogue:mousepressed(x, y, button)
    if button ~= 1 then return end
    -- A click on a choice option commits it; a click anywhere else advances the line.
    if self:choicesActive() and self.choiceRects then
        for i, r in ipairs(self.choiceRects) do
            if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
                self.choiceSel = i
                self:confirm()
                return
            end
        end
        -- Mid-choice, a stray click shouldn't advance past the prompt -- only snap the reveal.
        if not self.revealDone then self:confirm() end
        return
    end
    self:confirm()
end

-- Hand over a choice option; arrow elsewhere. See ui/cursor.lua.
function Dialogue:cursorKind(x, y)
    if self:choicesActive() and self.choiceRects then
        for _, r in ipairs(self.choiceRects) do
            if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
                return "hand"
            end
        end
    end
    return "arrow"
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

-- One cast member's portrait, standing on the box's top edge. `active` draws it in full colour;
-- otherwise it is greyed (a dark tint multiply on the image, a dim fill on the fallback box).
function Dialogue:drawPortrait(member, active)
    local image = member.image
    local baseY = self.boxY + 20 -- feet rest just inside the top of the text box
    if type(image) == "userdata" then
        local sw, sh = image:getDimensions()
        local scale = math.min(PORTRAIT_H / sh, (self.boxW / (#self.cast + 1)) / sw * 1.4)
        local tint = active and ACTIVE_TINT or INACTIVE_TINT
        love.graphics.setColor(tint[1], tint[2], tint[3])
        -- Origin at bottom-centre so the portrait hangs from baseY at its slot's centre.
        love.graphics.draw(image, member.centerX, baseY, 0, scale, scale, sw / 2, sh)
    else
        local w, h = 150, 300
        local fill = active and FALLBACK_ACTIVE or FALLBACK_INACTIVE
        love.graphics.setColor(fill[1], fill[2], fill[3])
        love.graphics.rectangle("fill", member.centerX - w / 2, baseY - h, w, h, 8, 8)
        love.graphics.setFont(self.fallbackFont)
        love.graphics.setColor(active and 0.92 or 0.5, active and 0.92 or 0.5, active and 0.96 or 0.55)
        -- First CHARACTER of the name (not first byte) -- a multibyte glyph must not be cut apart.
        local name = member.name or "?"
        local initial = name:sub(1, (utf8.offset(name, 2) or (#name + 1)) - 1)
        love.graphics.printf(initial, member.centerX - w / 2, baseY - h / 2 - 40, w, "center")
    end
end

function Dialogue:draw()
    -- Slight dim over the frozen screen behind, so the portraits and text read.
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local node = self:currentNode()
    local activeId = node and node.by

    -- Cast: inactive members first, the active speaker last so it sits on top.
    for _, member in ipairs(self.cast) do
        if member.id ~= activeId then self:drawPortrait(member, false) end
    end
    local activeMember = activeId and self.castById[activeId]
    if activeMember then self:drawPortrait(activeMember, true) end

    -- Scene title, top-left.
    if self.title then
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(0.95, 0.85, 0.55)
        love.graphics.print(self.title, 40, 28)
    end

    -- The text box.
    love.graphics.setColor(0.08, 0.09, 0.13, 0.92)
    love.graphics.rectangle("fill", self.boxX, self.boxY, self.boxW, self.boxH, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.7)
    love.graphics.rectangle("line", self.boxX, self.boxY, self.boxW, self.boxH, 10, 10)

    -- Speaker name plate, sitting on the top edge of the box near the active speaker's slot.
    local speakerName = (activeMember and activeMember.name)
        or (node and node.name)
        or (activeId and Conversation.speaker(activeId, node).name)
    if speakerName then
        love.graphics.setFont(self.nameFont)
        local plateW = self.nameFont:getWidth(speakerName) + 36
        local plateX = (activeMember and activeMember.centerX or self.boxX + 120) - plateW / 2
        plateX = math.max(self.boxX, math.min(plateX, self.boxX + self.boxW - plateW))
        local plateY = self.boxY - 20
        love.graphics.setColor(0.20, 0.34, 0.62)
        love.graphics.rectangle("fill", plateX, plateY, plateW, 32, 6, 6)
        love.graphics.setColor(0.95, 0.96, 1)
        love.graphics.printf(speakerName, plateX, plateY + 5, plateW, "center")
    end

    -- The (revealed slice of the) line -- sliced on a CHARACTER boundary so a multibyte glyph is
    -- never cut mid-sequence (which would be invalid UTF-8).
    local chars = math.floor(self.reveal)
    local byteEnd = (chars >= self.textLen) and #self.fullText or ((utf8.offset(self.fullText, chars + 1) or 1) - 1)
    local shown = self.fullText:sub(1, byteEnd)
    love.graphics.setFont(self.textFont)
    love.graphics.setColor(0.9, 0.9, 0.94)
    local textX = self.boxX + 28
    love.graphics.printf(shown, textX, self.boxY + 22, self.boxW - 56, "left")

    -- Branching choices, listed on the right side of the box once the line is out.
    self.choiceRects = nil
    if self:choicesActive() then
        self.choiceRects = {}
        local choices = node.choices
        love.graphics.setFont(self.choiceFont)
        local cw = 360
        local ch = 34
        local cx = self.boxX + self.boxW - cw - 24
        local startY = self.boxY - 12 - #choices * (ch + 8)
        for i, choice in ipairs(choices) do
            local cy = startY + (i - 1) * (ch + 8)
            local selected = i == self.choiceSel
            love.graphics.setColor(selected and 0.24 or 0.12, selected and 0.28 or 0.14, selected and 0.4 or 0.2, 0.95)
            love.graphics.rectangle("fill", cx, cy, cw, ch, 6, 6)
            love.graphics.setColor(selected and 0.7 or 0.4, selected and 0.78 or 0.45, selected and 0.95 or 0.6)
            love.graphics.rectangle("line", cx, cy, cw, ch, 6, 6)
            love.graphics.setColor(selected and 1 or 0.8, selected and 1 or 0.8, selected and 1 or 0.85)
            love.graphics.printf(self:textOf(choice), cx + 12, cy + 7, cw - 24, "left")
            self.choiceRects[i] = { x = cx, y = cy, w = cw, h = ch }
        end
    end

    -- Footer control hints, bottom-right of the box.
    local segs
    if self:choicesActive() then
        segs = InputMode.isGamepad()
            and { { glyph = "A", label = "Choose" }, { glyph = "B", label = "Skip" } }
            or { { glyph = "Enter", label = "Choose" }, { glyph = "Esc", label = "Skip" } }
    else
        segs = InputMode.isGamepad()
            and { { glyph = "A", label = "Advance" }, { glyph = "B", label = "Skip" } }
            or { { glyph = "Click", label = "Advance" }, { glyph = "Esc", label = "Skip" } }
    end
    ButtonPrompt.draw(segs, self.boxX, self.boxY + self.boxH - 26, self.boxW - 24, { align = "right" })

    love.graphics.setColor(1, 1, 1)
end

return Dialogue
