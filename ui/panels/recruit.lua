-- A BODY, WHOLE: the panel that puts one person in front of the player with everything about them
-- readable at once, and either one answer or two depending on who opened it.
--
-- TWO CALLERS, and they want opposite things from it. The Hiring Hall's summon
-- (ui/panels/hire_reveal.lua) opens it with `single = true` as the PAYOFF of a pull: the voucher is
-- spent, the body has already joined, and the panel is the reveal rather than a question -- one button,
-- and every dismissal routes to it. A caller that is genuinely ASKING (the descent's floor stop, which
-- is retired, and whatever asks next) opens it with two.
--
--   local panel = RecruitPanel.new({
--       title    = "Brann answers",
--       char     = result.char,                   -- the body itself, or Recruit.preview for a dry run
--       prompt   = "A voucher graded to floor 8.",
--       single   = true,                          -- one button; Esc/B/close all accept
--       onAccept = function() ... end,
--       onDecline = function() ... end,           -- two-answer callers only
--   })
--
-- WHY ONE BODY AND NOT A SLATE. This stop dealt three cards through ui/panels/choice.lua until now, and
-- three cards at a card's width apiece can hold a stat line and nothing else -- so the decision the stop
-- exists to ask ("what is this company short of") flattened into a comparison of four numbers between
-- strangers. One body gets the whole panel, and the whole panel is what a body is worth reading as: their
-- face, the four figures that say what they can take and deal, and THE KIT THEY ARE CARRYING laid out in
-- the same 3x3 grid they will fight out of, every piece of it readable. See models/descent_recruit.lua.
--
-- THE KIT IS THE ARGUMENT, so it is inspectable rather than summarized. Hover any slot with the mouse, or
-- walk the pieces with Up/Down on a keyboard or pad, and the shared ItemTooltip opens on it -- the same
-- box the battle screen and the loadout use, so what a player learned to read there reads here. The two
-- pieces the blueprint names as its signature pair (`signatureWeapon` / `signatureAbility` -- the two
-- items that ARE this unit) wear a gold ring in the grid, and the sentence beside the stats names them:
-- the ring says WHICH, the sentence says WHAT, and neither is asked to do both jobs.
--
-- Three-input + mouse-only, and the two axes never fight: Left/Right picks between the two answers,
-- Up/Down inspects the kit, Enter/A commits the picked answer, Esc/B/X walks on.

local CloseButton = require("ui.close_button")
local Discipline = require("models.discipline")
local Glossary = require("models.glossary")
local GlossaryPanel = require("ui.glossary_panel")
local InputMode = require("input_mode")
local Item = require("models.item")
local ItemTooltip = require("ui.item_tooltip")
local Scale = require("scale")
local Theme = require("ui.theme")

local RecruitPanel = {}
RecruitPanel.__index = RecruitPanel

local PAD = 26
local COL_GAP = 18
-- The face pane, SQUARE. Most of this pool is generic class templates, whose art is a board token in a
-- square frame rather than a painted VN portrait -- a tall pane hangs half a card of empty air under
-- them. A real portrait (a companion's) is taller than it is wide and simply fits inside the square.
local PORTRAIT_W, PORTRAIT_H = 168, 168
local SLOT, SLOT_GAP = 44, 5
local GRID_W = 3 * SLOT + 2 * SLOT_GAP
local BOX_W = 640
local STATS_W = BOX_W - PAD * 2 - PORTRAIT_W - GRID_W - COL_GAP * 2
local BTN_W, BTN_H, BTN_GAP = 176, 44, 16
local ROW_H = 23 -- one stat line: label left, figure right
-- Room kept under a tooltip for the definitions of whatever it just named (statuses, keywords). Two
-- entries' worth: past that the glossary trims itself and says how many it dropped, which is its job.
local GLOSS_MIN = 150

local function inRect(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- A resource stat is a { max, current } pool and a flat stat is a number; a body met on a floor is
-- always at full, so the pool's max is the honest figure either way.
local function statValue(stats, key)
    local v = stats and stats[key]
    if type(v) == "table" then return v.max or v.current or 0 end
    return v or 0
end

-- What to call this body's house: the deeper cut if it has one, else the shelf it came off. Both are
-- already-authored display names -- nothing here invents wording for a class.
local function houseOf(char)
    return (char.discipline and Discipline.displayName(char.discipline))
        or Item.classDisplayName(char.class)
end

function RecruitPanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, RecruitPanel)
    self.char = opts.char
    self.title = opts.title or "Someone Still Standing"
    self.prompt = opts.prompt
    self.acceptLabel = opts.acceptLabel or "Take them on"
    self.declineLabel = opts.declineLabel or "Walk on"
    self.onAccept = opts.onAccept
    self.onDecline = opts.onDecline
    self.finished = false

    -- ONE ANSWER INSTEAD OF TWO, for the caller that is not asking a question.
    --
    -- A floor stop asked one -- take them on, or walk on -- and both buttons were real. The summon
    -- (ui/panels/hire_reveal.lua) is not asking anything: the voucher is already spent, the body is
    -- already in the company, and this panel is what the player is being SHOWN. A refusal button on a
    -- reveal offers to undo something that cannot be undone, so `single` draws one centred button and
    -- routes every dismissal -- Esc, B, the close corner -- to accept.
    --
    -- The kit cursor is untouched by this: reading the pieces is the whole reason the reveal borrows
    -- this panel rather than drawing a portrait and a name.
    self.single = opts.single == true
    if self.single then self.acceptLabel = opts.acceptLabel or "Welcome" end

    -- WHO OWNS THE GROUND UNDER THIS. A floor stop opens this panel over a live battle map, so the
    -- panel lays its own scrim over it. The crossing opens it over its own much darker one with the
    -- rift still burning behind the card (ui/panels/hire_reveal.lua), and a second veil there would
    -- dim the one thing the card is supposed to be standing in front of. `scrim = false` says the
    -- caller has already darkened the room.
    self.scrim = opts.scrim ~= false

    self.choice = 1     -- 1 = take, 2 = walk on. The panel opens on the offer, not on the refusal.
    self.peek = nil     -- keyboard/pad kit cursor: an index into self.slots, or nil for "nothing open"
    self.hover = nil    -- the slot the mouse is over, which outranks the peek while it lasts

    self.titleFont = Theme.display(28)
    self.promptFont = Theme.body(15)
    self.nameFont = Theme.display(24)
    self.houseFont = Theme.body(13)
    self.rowFont = Theme.body(14)
    self.kitFont = Theme.body(12)
    self.initFont = Theme.display(18)
    self.btnFont = Theme.body(15)
    self.hintFont = Theme.body(13)

    local char = self.char or {}
    self.name = char.name or "A survivor"
    -- The house, unless the house is what the body is CALLED. Half this pool is the generic template of
    -- its own class ("Crusader", a Crusader), and "Crusader · Level 1" under the word Crusader spends a
    -- line saying nothing.
    self.house = houseOf(char)
    if self.house == self.name then self.house = nil end
    self.subtitle = (self.house and (self.house .. "  ·  ") or "") .. "Level " .. (char.level or 1)

    local stats = char.stats
    self.rows = {
        { "Health", statValue(stats, "health") },
        { "Damage", statValue(stats, "damage") },
        { "Defense", statValue(stats, "defense") },
        { "Move", statValue(stats, "movement") },
    }

    -- The signature pair, by item id, for the ring in the grid and the sentence beside it. Read off the
    -- instantiated body rather than the blueprint: Character.instantiate carries both fields through,
    -- and a body that names neither (a plain template with no signature verb) simply rings nothing.
    self.signature = {}
    local named = {}
    for _, id in ipairs({ char.signatureWeapon, char.signatureAbility }) do
        if id then self.signature[id] = true end
    end
    for cell = 1, 9 do
        local item = char.inventory and char.inventory[cell]
        if item and self.signature[item.id] then named[#named + 1] = item.name or item.id end
    end
    self.fights = #named > 0 and ("Fights with " .. table.concat(named, " and ") .. ".") or nil

    -- ---- geometry ----------------------------------------------------------
    self.oPrompt = 58
    self.promptH = 0
    if self.prompt then
        local _, lines = self.promptFont:getWrap(self.prompt, BOX_W - PAD * 2)
        self.promptH = math.max(1, #lines) * self.promptFont:getHeight()
    end
    self.oBody = self.oPrompt + self.promptH + 16

    -- The stats column, measured so the body region is as tall as its tallest column and never taller.
    self.oName = 0
    self.oHouse = self.oName + self.nameFont:getHeight() + 2
    self.oRows = self.oHouse + self.houseFont:getHeight() + 12
    self.oFights = self.oRows + #self.rows * ROW_H + 10
    local statsH = self.oFights
    if self.fights then
        local _, lines = self.kitFont:getWrap(self.fights, STATS_W)
        statsH = statsH + #lines * self.kitFont:getHeight()
    end

    local kitH = self.kitFont:getHeight() + 6 + GRID_W -- caption + a square grid
    self.bodyH = math.max(PORTRAIT_H, statsH, kitH)

    self.oButtons = self.oBody + self.bodyH + 20
    self.oHint = self.oButtons + BTN_H + 12
    self.boxW = BOX_W
    self.boxH = self.oHint + self.hintFont:getHeight() + PAD - 8
    self.boxX = math.floor(Scale.WIDTH / 2 - self.boxW / 2)
    self.boxY = math.floor(Scale.HEIGHT / 2 - self.boxH / 2)

    local bodyY = self.boxY + self.oBody
    self.portrait = { x = self.boxX + PAD, y = bodyY, w = PORTRAIT_W, h = PORTRAIT_H }
    self.statsX = self.portrait.x + PORTRAIT_W + COL_GAP
    self.statsY = bodyY + 2
    self.gridX = self.statsX + STATS_W + COL_GAP
    self.gridY = bodyY + self.kitFont:getHeight() + 6

    -- Every occupied cell, in reading order, as a hit rect carrying its item. The list is what both the
    -- mouse and the kit cursor walk, so an empty cell is never something the cursor stops on.
    self.slots = {}
    for cell = 1, 9 do
        local item = char.inventory and char.inventory[cell]
        if item then
            local col, row = (cell - 1) % 3, math.floor((cell - 1) / 3)
            self.slots[#self.slots + 1] = {
                x = self.gridX + col * (SLOT + SLOT_GAP), y = self.gridY + row * (SLOT + SLOT_GAP),
                w = SLOT, h = SLOT, item = item, key = self.signature[item.id] or false,
            }
        end
    end

    local by = self.boxY + self.oButtons
    if self.single then
        -- Centred on the card rather than sitting where the left of a pair would: a lone button parked
        -- off-centre reads as one half of a row whose other half failed to draw.
        self.takeBtn = { x = self.boxX + self.boxW / 2 - BTN_W / 2, y = by, w = BTN_W, h = BTN_H }
        self.leaveBtn = { x = -1000, y = -1000, w = 0, h = 0 } -- off-screen: never hit, never drawn
    else
        local totalW = BTN_W * 2 + BTN_GAP
        self.takeBtn = { x = self.boxX + self.boxW / 2 - totalW / 2, y = by, w = BTN_W, h = BTN_H }
        self.leaveBtn = { x = self.takeBtn.x + BTN_W + BTN_GAP, y = by, w = BTN_W, h = BTN_H }
    end

    self.closeButton = CloseButton.new(self.boxX + self.boxW, self.boxY)
    return self
end

function RecruitPanel:accept()
    if self.finished then return end
    self.finished = true
    if self.onAccept then self.onAccept() end
end

-- Every dismissal lands here, which is why `single` intercepts it rather than hiding the button: Esc, B
-- and the close corner all walk on, and on a reveal there is nothing to walk on FROM.
function RecruitPanel:decline()
    if self.finished then return end
    if self.single then return self:accept() end
    self.finished = true
    if self.onDecline then self.onDecline() end
end

function RecruitPanel:commit()
    if self.single or self.choice == 1 then self:accept() else self:decline() end
end

-- The item the tooltip is open on: whatever the mouse is over, else whatever the kit cursor is parked on.
function RecruitPanel:openSlot()
    return self.slots[self.hover or self.peek or 0]
end

-- ---- drawing ----------------------------------------------------------------

function RecruitPanel:drawPortrait()
    local r = self.portrait
    Theme.fill(Theme.slot, r.x, r.y, r.w, r.h, 5)

    local char = self.char or {}
    local art = char.portrait
    if type(art) ~= "userdata" then art = char.sprite end
    if type(art) == "userdata" then
        local iw, ih = art:getDimensions()
        local scale = math.min((r.w - 10) / iw, (r.h - 10) / ih)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(art, r.x + r.w / 2, r.y + r.h / 2, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Art missing (Sprite.load hands back the path when the file is not there): the letter token
        -- every other surface falls back to, so a body with no painted face still has a face-shaped
        -- thing where its face goes.
        love.graphics.setColor(0.30, 0.32, 0.40)
        love.graphics.rectangle("fill", r.x + 34, r.y + 34, r.w - 68, r.h - 68, 6, 6)
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(0.90, 0.90, 0.95)
        love.graphics.printf(self.name:sub(1, 1), r.x, r.y + r.h / 2 - 22, r.w, "center")
    end

    Theme.set(Theme.hairline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
end

function RecruitPanel:drawStats()
    local x, y, w = self.statsX, self.statsY, STATS_W

    local font, label = Theme.fitText(Theme.display, self.name, w, 24, 16)
    love.graphics.setFont(font)
    Theme.set(Theme.ink)
    love.graphics.print(label, x, y + self.oName)

    love.graphics.setFont(self.houseFont)
    Theme.set(Theme.muted)
    love.graphics.print(Theme.ellipsize(self.subtitle, self.houseFont, w), x, y + self.oHouse)

    love.graphics.setFont(self.rowFont)
    for i, row in ipairs(self.rows) do
        local ry = y + self.oRows + (i - 1) * ROW_H
        Theme.set(Theme.hairline)
        love.graphics.rectangle("fill", x, ry + ROW_H - 4, w, 1)
        Theme.set(Theme.muted)
        love.graphics.print(row[1], x, ry)
        Theme.set(Theme.ink)
        love.graphics.printf(tostring(row[2]), x, ry, w, "right")
    end

    if self.fights then
        love.graphics.setFont(self.kitFont)
        Theme.set(Theme.accentAmber, 0.85)
        love.graphics.printf(self.fights, x, y + self.oFights, w, "left")
    end
end

function RecruitPanel:drawKit()
    love.graphics.setFont(self.kitFont)
    Theme.set(Theme.muted)
    love.graphics.print("Carries", self.gridX, self.gridY - self.kitFont:getHeight() - 5)

    local open = self:openSlot()
    for cell = 1, 9 do
        local col, row = (cell - 1) % 3, math.floor((cell - 1) / 3)
        local sx = self.gridX + col * (SLOT + SLOT_GAP)
        local sy = self.gridY + row * (SLOT + SLOT_GAP)
        Theme.fill(Theme.slot, sx, sy, SLOT, SLOT, 5)
    end

    for _, slot in ipairs(self.slots) do
        local item = slot.item
        local icx, icy = slot.x + SLOT / 2, slot.y + SLOT / 2
        if type(item.sprite) == "userdata" then
            love.graphics.setColor(1, 1, 1)
            local iw, ih = item.sprite:getDimensions()
            local scale = math.min((SLOT - 8) / iw, (SLOT - 8) / ih)
            love.graphics.draw(item.sprite, icx, icy, 0, scale, scale, iw / 2, ih / 2)
        else
            local ph = SLOT - 14
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.rectangle("fill", icx - ph / 2, icy - ph / 2, ph, ph, 4, 4)
            love.graphics.setFont(self.initFont)
            love.graphics.setColor(0.95, 0.95, 0.98)
            love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 10, ph, "center")
        end

        -- Gold for the signature pair (a standing property of the body), steel for the cursor or the
        -- mouse (a selection that moves) -- the two rings this project keeps apart everywhere else.
        if slot.key then
            Theme.set(Theme.accentAmber, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slot.x, slot.y, SLOT, SLOT, 5, 5)
        end
        if slot == open then
            Theme.set(Theme.cursor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slot.x - 2, slot.y - 2, SLOT + 4, SLOT + 4, 6, 6)
        end
        love.graphics.setLineWidth(1)
    end
end

function RecruitPanel:drawButton(b, label, picked, accent)
    Theme.set(accent, picked and 0.28 or 0.12)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
    Theme.set(accent, picked and 1 or 0.55)
    love.graphics.setLineWidth(picked and 2 or 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.btnFont)
    Theme.set(Theme.ink)
    love.graphics.printf(label, b.x, b.y + b.h / 2 - self.btnFont:getHeight() / 2, b.w, "center")
end

function RecruitPanel:draw()
    if self.scrim then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    end

    local bx, by = self.boxX, self.boxY
    Theme.plate(bx, by, self.boxW, self.boxH, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, bx, by + 16, self.boxW, "center")

    if self.prompt then
        love.graphics.setFont(self.promptFont)
        Theme.set(Theme.muted)
        love.graphics.printf(self.prompt, bx + PAD, by + self.oPrompt, self.boxW - PAD * 2, "center")
    end

    self:drawPortrait()
    self:drawStats()
    self:drawKit()

    -- Amber for the offer, quiet bronze for the refusal. The steel ring is spoken for -- it is the kit
    -- cursor two inches above these buttons, and a button wearing it would read as "the cursor is here".
    self:drawButton(self.takeBtn, self.acceptLabel, self.single or self.choice == 1, Theme.accentAmber)
    if not self.single then
        self:drawButton(self.leaveBtn, self.declineLabel, self.choice == 2, Theme.muted)
    end

    local hint
    if self.single then
        hint = InputMode.isGamepad()
            and "Up/Down read the kit  -  A continue"
            or "Up/Down read the kit  -  Enter continue"
    else
        hint = InputMode.isGamepad()
            and "D-pad choose  -  Up/Down read the kit  -  A confirm  -  B walk on"
            or "Left/Right choose  -  Up/Down read the kit  -  Enter confirm  -  Esc walk on"
    end
    love.graphics.setFont(self.hintFont)
    Theme.set(Theme.muted, 0.85)
    love.graphics.printf(hint, bx, by + self.oHint, self.boxW, "center")

    self.closeButton:draw()

    -- Last, over everything: the piece being read, in a COLUMN OF ITS OWN beside the card. Not hung off
    -- the mouse and not off the slot -- either way it opens on top of the grid it is describing, so
    -- reading the second piece means covering the first three. The column is pinned to the card's right
    -- edge, at the height of the slot that opened it, and holds the same box every other surface uses
    -- with its definitions stacked UNDERNEATH rather than beside (GlossaryPanel's own beside-the-box
    -- rule has one tooltip's worth of room in mind, and would flip the definitions back over the kit).
    local open = self:openSlot()
    local layout = open and ItemTooltip.measure(open.item)
    if layout then
        local entries = Glossary.forItem(open.item, nil, layout.out)
        local hasDefs = entries and #entries > 0
        -- The column opens at the height of the slot that asked for it, and is RAISED when there are
        -- definitions coming: a tall tooltip hung level with the bottom row leaves nothing under it, and
        -- the glossary's own answer to "no room" is to drop the definitions silently. Room is taken out
        -- of the tooltip's position instead, which costs nothing but a few pixels of alignment.
        local floorY = Scale.HEIGHT - 4 - layout.h - (hasDefs and GLOSS_MIN or 0)
        local y = math.max(4, math.min(open.y - 24, floorY))
        local box = ItemTooltip.paint(layout, self.boxX + self.boxW + 12, y)
        if box and hasDefs then
            local below = box.y + box.h + 8
            GlossaryPanel.drawAt(entries, box.x, below, Scale.HEIGHT - below - 8)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------

function RecruitPanel:slotAt(x, y)
    for i, slot in ipairs(self.slots) do
        if inRect(slot, x, y) then return i end
    end
    return nil
end

function RecruitPanel:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    self.hover = self:slotAt(x, y)
    -- Moving the mouse onto a button picks it, the way every other panel here behaves; moving it over
    -- the kit does not, so reading a piece never quietly re-aims the answer you are about to confirm.
    if inRect(self.takeBtn, x, y) then self.choice = 1
    elseif inRect(self.leaveBtn, x, y) then self.choice = 2 end
end

function RecruitPanel:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    if inRect(self.takeBtn, x, y) or inRect(self.leaveBtn, x, y) then return "hand" end
    if self:slotAt(x, y) then return "hand" end
    return "arrow"
end

function RecruitPanel:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:decline(); return end
    if inRect(self.takeBtn, x, y) then self:accept(); return end
    if inRect(self.leaveBtn, x, y) then self:decline(); return end
    -- A click on a piece PINS its tooltip, so a mouse-only player can read one and then move the pointer
    -- to the button without the box closing on the way.
    local slot = self:slotAt(x, y)
    if slot then self.peek = (self.peek == slot) and nil or slot end
end

-- The kit cursor walks the carried pieces and then off the end of them: nil -> 1 -> ... -> n -> nil. The
-- empty state is a real stop rather than a wrap, because "no tooltip open" is the state the panel opened
-- in and there has to be a way back to it without a mouse.
function RecruitPanel:movePeek(d)
    local n = #self.slots
    if n == 0 then return end
    local i = (self.peek or 0) + d
    if i < 0 then i = n elseif i > n then i = 0 end
    self.peek = i > 0 and i or nil
    self.hover = nil
end

function RecruitPanel:keypressed(key)
    if key == "escape" then self:decline()
    elseif key == "left" or key == "a" then self.choice = 1
    elseif key == "right" or key == "d" then self.choice = 2
    elseif key == "up" or key == "w" then self:movePeek(-1)
    elseif key == "down" or key == "s" then self:movePeek(1)
    elseif key == "return" or key == "kpenter" or key == "space" then self:commit() end
end

function RecruitPanel:gamepadpressed(_, button)
    if button == "b" then self:decline()
    elseif button == "dpleft" then self.choice = 1
    elseif button == "dpright" then self.choice = 2
    elseif button == "dpup" then self:movePeek(-1)
    elseif button == "dpdown" then self:movePeek(1)
    elseif button == "a" or button == "start" then self:commit() end
end

return RecruitPanel
