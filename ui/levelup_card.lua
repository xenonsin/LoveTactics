-- THE LEVEL-UP CARD: Fire Emblem Heroes' level-up screen, played over a dimmed battlefield.
--
-- A body's full-length art fills most of the frame from the left; a glowing stat box sits bottom-right,
-- headed "Lv N -> N+1", with the name and class under it and every stat in a column. Only the stats that
-- GREW get a "+N" chip, popping in one after another, and their values turn gold. There is no class-rung
-- line: the rung is the board's own floater (states/battle.lua's releaseGrowthAward) and the summary's.
--
-- The same layout is the CLASS-UNLOCK ceremony (LevelupCard.showUnlock): a "Class Unlocked" banner and
-- the new class's title head the box, and the chips are the class's stat boost.
--
-- ---------------------------------------------------------------------------------------------------
-- HOST CONTRACT -- read this before hosting a card anywhere
-- ---------------------------------------------------------------------------------------------------
--
--   local LevelupCard = require("ui.levelup_card")
--
--   card = LevelupCard.forLevel(char, summary [, opts])     -- summary = Growth.resolve's return
--   card = LevelupCard.showUnlock(char, classId, boosts [, opts])
--          -- boosts = { damage = 2, health = 4, ... } (any stat key; zero/nil entries get no chip)
--          -- opts.values = { stat = shownValue } overrides the figures (default Character.statTotal)
--          -- opts.title  = class title override (default Class.displayName(classId))
--   card:update(dt)                       -- every frame while it is up
--   card:draw()                           -- LAST, over everything; it dims the whole 1280x720 frame
--   card:keypressed(key)                  -- \
--   card:gamepadpressed(joystick, button) --  > each returns true (the card eats every input while up)
--   card:mousepressed(x, y, button)       -- /   a finger is a mouse here: a tap is a click
--   card:mousemoved()                     -- swallowed (true)
--   card.done                             -- true once dismissed: drop it and resume the host
--
--   The FIRST press (click / tap / confirm / Space / Esc / A / B) reveals everything and skips the
--   animation; the SECOND dismisses. `card:press()` is that one verb, for a host with its own input.
--
--   For several in a row (one per levelled body), LevelupCard.queue() returns an object with the same
--   five methods plus :push(card), :active() and :clear(); it plays its cards in push order and is idle
--   (:active() == false) when the last is dismissed.
--
-- Nothing here touches love.graphics at require time, so the module loads under the headless runner and
-- every non-draw method (rows, the reveal/dismiss machine, the queue) is spec'd (tests/levelup_card_spec).
-- It works outside a battle: it reads only the character and Scale's logical 1280x720 space.

local Theme = require("ui.theme")
local Scale = require("scale")

local LevelupCard = {}
LevelupCard.__index = LevelupCard

-- Stat names and order: the advancement panel's and the Loadout sheet's (ui/panels/advancement.lua).
LevelupCard.STAT_ORDER = { "health", "mana", "stamina", "damage", "magicDamage", "defense", "magicDefense",
    "movement", "speed" }
LevelupCard.STAT_LABEL = {
    health = "HP", mana = "MP", stamina = "SP",
    damage = "Attack", magicDamage = "Magic",
    defense = "Defense", magicDefense = "M.Def",
    movement = "Move", speed = "Speed",
}

-- The animation, in seconds. The art slides in, the box rises after it, then the chips pop one by one.
LevelupCard.ART_IN = 0.35
LevelupCard.BOX_AT = 0.2
LevelupCard.BOX_IN = 0.3
LevelupCard.CHIP_AT = 0.7
LevelupCard.CHIP_GAP = 0.16
LevelupCard.CHIP_POP = 0.22

-- Geometry, in the logical 1280x720 space.
local BOX_W, ROW_H, HEAD_H, PAD = 380, 30, 96, 16
local BOX_H = HEAD_H + #LevelupCard.STAT_ORDER * ROW_H + PAD
-- The box's corner, read per frame: Scale.WIDTH/HEIGHT is the CURRENT logical space, which the
-- handheld arrangement shortens (scale.lua), so nothing here may be fixed at require time.
local function boxOrigin()
    return Scale.WIDTH - BOX_W - 48, math.max(12, Scale.HEIGHT - BOX_H - 44)
end
local PILL_W = 92

-- One row per stat: `{ stat, label, value, gain }`, gain > 0 only on a stat that grew. `values` maps a
-- stat to the figure shown AFTER the change; `gains` maps a stat to what it grew by.
function LevelupCard.rows(values, gains)
    local rows = {}
    for _, stat in ipairs(LevelupCard.STAT_ORDER) do
        local gain = (gains and gains[stat]) or 0
        rows[#rows + 1] = {
            stat = stat, label = LevelupCard.STAT_LABEL[stat],
            value = (values and values[stat]) or 0,
            gain = gain > 0 and gain or 0,
        }
    end
    return rows
end

-- The figure a stat reads on the card: the effective number the Loadout sheet prints (gear folded in,
-- the ceiling for a pool), so the card and the sheet never quote two numbers for one stat.
local function valuesOf(char)
    local Character = require("models.character")
    local values = {}
    for _, stat in ipairs(LevelupCard.STAT_ORDER) do values[stat] = Character.statTotal(char, stat) end
    return values
end

local function classTitle(classId)
    if not classId then return "" end
    local ok, Class = pcall(require, "models.class")
    local name = ok and Class.displayName and Class.displayName(classId)
    return name or (tostring(classId):gsub("_", " "):gsub("^%l", string.upper))
end

-- The art: the blueprint's optional full-length `levelupArt`, else the board token scaled up.
local function artOf(char)
    local path = char.levelupArt
    if not path and char.id then
        local ok, Character = pcall(require, "models.character")
        local def = ok and Character.defs and Character.defs[char.id]
        path = def and def.levelupArt
    end
    if path then
        local img = require("models.sprite").load(path)
        if type(img) == "userdata" then return img, false end
    end
    local okC, Character = pcall(require, "models.character")
    local token = okC and Character.spriteOf and Character.spriteOf(char)
    if type(token) == "userdata" then return token, true end
    return nil, true
end

local function new(fields)
    local self = setmetatable(fields, LevelupCard)
    self.t = 0
    self.revealed = false
    self.done = false
    self.chimed = false
    local n = 0
    for _, row in ipairs(self.rows) do if row.gain > 0 then n = n + 1 end end
    self.chipCount = n
    self.finish = n > 0
        and (LevelupCard.CHIP_AT + (n - 1) * LevelupCard.CHIP_GAP + LevelupCard.CHIP_POP)
        or (LevelupCard.BOX_AT + LevelupCard.BOX_IN)
    -- The sound, injectable so a spec can count it without an audio device.
    self.playSound = self.playSound or function(id)
        local ok, Sound = pcall(require, "models.sound")
        if ok and Sound.play then Sound.play(id) end
    end
    return self
end

-- A LEVEL-UP. `summary` is what Growth.resolve returned ({ fromLevel, toLevel, class, gains }).
function LevelupCard.forLevel(char, summary, opts)
    opts = opts or {}
    local values = opts.values or valuesOf(char)
    return new({
        kind = "level",
        char = char,
        name = char.name or char.id or "?",
        fromLevel = summary.fromLevel, toLevel = summary.toLevel,
        classTitle = classTitle(summary.class),
        rows = LevelupCard.rows(values, summary.gains),
        playSound = opts.playSound,
    })
end

-- THE CLASS-UNLOCK CEREMONY, for the Armory's class editor (ui/class_editor.lua) or any host. Same
-- layout; the head reads "Class Unlocked" over the class title, and the chips are `boosts`.
function LevelupCard.showUnlock(char, classId, boosts, opts)
    opts = opts or {}
    local values = opts.values or valuesOf(char)
    return new({
        kind = "unlock",
        char = char,
        name = char.name or char.id or "?",
        classId = classId,
        classTitle = opts.title or classTitle(classId),
        rows = LevelupCard.rows(values, boosts),
        playSound = opts.playSound,
    })
end

-- The cards a batch of mid-fight level-ups owes: one per `{ unit, summary }` (Experience.resolveOnBoard's
-- rows), in order, EXCEPT where `isAuto(unit)` says the AI is driving that body -- an auto-played fight
-- applies its levels silently and shows no card, during the fight or after it.
function LevelupCard.cardsFor(ups, isAuto, opts)
    local cards = {}
    for _, up in ipairs(ups or {}) do
        if not (isAuto and isAuto(up.unit)) then
            cards[#cards + 1] = LevelupCard.forLevel(up.unit.char, up.summary, opts)
        end
    end
    return cards
end

-- When chip `i` (1-based, among grown rows) starts popping.
function LevelupCard:chipStart(i)
    return LevelupCard.CHIP_AT + (i - 1) * LevelupCard.CHIP_GAP
end

function LevelupCard:update(dt)
    if self.done then return end
    self.t = self.t + (dt or 0)
    if not self.chimed and self.chipCount > 0 and self.t >= LevelupCard.CHIP_AT then
        self.chimed = true
        self.playSound("quest.levelup")
    end
    if self.t >= self.finish then self.revealed = true end
end

-- The one verb: reveal on the first press, dismiss on the second. Returns "revealed" or "dismissed".
function LevelupCard:press()
    if self.done then return "dismissed" end
    if not self.revealed then
        self.t = math.max(self.t, self.finish)
        self.revealed = true
        if not self.chimed and self.chipCount > 0 then
            self.chimed = true
            self.playSound("quest.levelup")
        end
        return "revealed"
    end
    self.done = true
    return "dismissed"
end

local CONFIRM_KEYS = { ["return"] = true, kpenter = true, space = true, escape = true, z = true, x = true }
function LevelupCard:keypressed(key)
    if CONFIRM_KEYS[key] then self:press() end
    return true
end

function LevelupCard:gamepadpressed(_, button)
    if button == "a" or button == "b" or button == "start" then self:press() end
    return true
end

function LevelupCard:mousepressed(_, _, button)
    if button == nil or button == 1 or button == 2 then self:press() end
    return true
end

function LevelupCard:mousemoved() return true end
function LevelupCard:wheelmoved() return true end

-- ---------------------------------------------------------------------------------------------- draw

local function ease(x)
    x = math.max(0, math.min(1, x))
    return 1 - (1 - x) * (1 - x) * (1 - x)
end

function LevelupCard:drawArt(a)
    local img, isToken = artOf(self.char)
    local slide = ease(self.t / LevelupCard.ART_IN)
    local boxX = boxOrigin()
    local areaW, areaH = boxX - 40, Scale.HEIGHT - 20
    local cx = 40 + areaW / 2 - (1 - slide) * 220
    if img then
        local iw, ih = img:getDimensions()
        local scale = math.min(areaW / iw, areaH / ih)
        if isToken then scale = math.min(scale, (Scale.HEIGHT * 0.82) / ih) end
        local r, g, b = 1, 1, 1
        local okC, Character = pcall(require, "models.character")
        if okC and Character.tintOf then
            local tint = Character.tintOf(self.char)
            if type(tint) == "table" then r, g, b = tint[1] or 1, tint[2] or 1, tint[3] or 1 end
        end
        love.graphics.setColor(r, g, b, a * slide)
        love.graphics.draw(img, cx, Scale.HEIGHT, 0, scale, scale, iw / 2, ih)
    else
        -- No art at all: a tall plate with the initial, so the frame is still somebody.
        local w, h = 300, 520
        Theme.set(Theme.panel2, a * slide)
        love.graphics.rectangle("fill", cx - w / 2, Scale.HEIGHT - h - 40, w, h, 8, 8)
        Theme.set(Theme.accentAmber, a * slide)
        love.graphics.setFont(Theme.display(120))
        love.graphics.printf(self.name:sub(1, 1), cx - w / 2, Scale.HEIGHT - h / 2 - 110, w, "center")
    end
end

function LevelupCard:draw()
    if self.done then return end
    local t = self.t
    local dim = ease(t / LevelupCard.ART_IN)
    love.graphics.setColor(0, 0, 0, 0.62 * dim)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    self:drawArt(1)

    local boxA = ease((t - LevelupCard.BOX_AT) / LevelupCard.BOX_IN)
    if boxA <= 0 then love.graphics.setColor(1, 1, 1); return end
    local bx, by0 = boxOrigin()
    local by = by0 + (1 - boxA) * 24

    -- The glow: soft amber rings behind the plate, breathing once revealed.
    local breathe = self.revealed and (0.8 + 0.2 * math.sin(t * 3)) or 1
    for i = 4, 1, -1 do
        Theme.set(Theme.accentAmber, 0.07 * boxA * breathe)
        love.graphics.rectangle("fill", bx - i * 5, by - i * 5, BOX_W + i * 10, BOX_H + i * 10, 8 + i * 3,
            8 + i * 3)
    end
    Theme.set(Theme.panel, 0.96 * boxA)
    love.graphics.rectangle("fill", bx, by, BOX_W, BOX_H, 6, 6)
    Theme.set(Theme.accentAmber, 0.85 * boxA)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, BOX_W, BOX_H, 6, 6)
    love.graphics.setLineWidth(1)

    -- Head.
    local head = Theme.display(30)
    local sub = Theme.body(16)
    love.graphics.setFont(head)
    Theme.set(Theme.accentAmber, boxA)
    if self.kind == "unlock" then
        love.graphics.printf("Class Unlocked", bx + PAD, by + 10, BOX_W - PAD * 2, "left")
        love.graphics.setFont(sub)
        Theme.set(Theme.ink, boxA)
        love.graphics.print(self.classTitle .. "  \194\183  " .. self.name, bx + PAD, by + 10 + head:getHeight() + 4)
    else
        love.graphics.printf("Lv " .. tostring(self.fromLevel) .. "  \226\134\146  " .. tostring(self.toLevel),
            bx + PAD, by + 10, BOX_W - PAD * 2, "left")
        love.graphics.setFont(sub)
        Theme.set(Theme.ink, boxA)
        local line = self.name
        if self.classTitle ~= "" then line = line .. "  \194\183  " .. self.classTitle end
        love.graphics.print(line, bx + PAD, by + 10 + head:getHeight() + 4)
    end
    Theme.set(Theme.hairline, boxA)
    love.graphics.line(bx + PAD, by + HEAD_H - 8, bx + BOX_W - PAD, by + HEAD_H - 8)

    -- Rows.
    local labelF, valueF, chipF = Theme.body(14), Theme.display(20), Theme.body(15)
    local chipIdx = 0
    for i, row in ipairs(self.rows) do
        local ry = by + HEAD_H + (i - 1) * ROW_H
        local px, ph = bx + PAD, ROW_H - 8
        Theme.set(Theme.panel2, boxA)
        love.graphics.rectangle("fill", px, ry + 4, PILL_W, ph, ph / 2, ph / 2)
        love.graphics.setFont(labelF)
        Theme.set(Theme.muted, boxA)
        love.graphics.printf(row.label, px, ry + 4 + (ph - labelF:getHeight()) / 2, PILL_W, "center")

        local popped = 0
        if row.gain > 0 then
            chipIdx = chipIdx + 1
            popped = ease((t - self:chipStart(chipIdx)) / LevelupCard.CHIP_POP)
        end
        love.graphics.setFont(valueF)
        local valueX, valueW = px + PILL_W + 12, 60
        if popped > 0 then Theme.set(Theme.accentAmber, boxA) else Theme.set(Theme.ink, boxA) end
        love.graphics.printf(tostring(row.value), valueX, ry + (ROW_H - valueF:getHeight()) / 2, valueW, "right")

        if popped > 0 then
            local text = "+" .. row.gain
            local cw = chipF:getWidth(text) + 16
            local cx = valueX + valueW + 14
            local cy = ry + 4 + (1 - popped) * 10
            Theme.set(Theme.accentAmber, boxA * popped)
            love.graphics.rectangle("fill", cx, cy, cw, ph, ph / 2, ph / 2)
            love.graphics.setFont(chipF)
            Theme.set(Theme.mount, boxA * popped)
            love.graphics.printf(text, cx, cy + (ph - chipF:getHeight()) / 2, cw, "center")
        end
    end

    if self.revealed then
        love.graphics.setFont(Theme.body(13))
        Theme.set(Theme.muted, 0.6 + 0.4 * math.sin(t * 4))
        love.graphics.printf("Continue", bx, by + BOX_H + 10, BOX_W - PAD, "right")
    end
    love.graphics.setColor(1, 1, 1)
end

-- --------------------------------------------------------------------------------------------- queue

local Queue = {}
Queue.__index = Queue

function LevelupCard.queue()
    return setmetatable({ items = {} }, Queue)
end

function Queue:push(card) if card then self.items[#self.items + 1] = card end end
function Queue:current() return self.items[1] end
function Queue:active() return self.items[1] ~= nil end
function Queue:clear() self.items = {} end

local function settle(q)
    while q.items[1] and q.items[1].done do table.remove(q.items, 1) end
end

function Queue:update(dt)
    settle(self)
    if self.items[1] then self.items[1]:update(dt) end
end

function Queue:draw()
    if self.items[1] then self.items[1]:draw() end
end

local function forward(name)
    return function(self, ...)
        local card = self.items[1]
        if not card then return false end
        card[name](card, ...)
        settle(self)
        return true
    end
end
Queue.keypressed = forward("keypressed")
Queue.gamepadpressed = forward("gamepadpressed")
Queue.mousepressed = forward("mousepressed")
Queue.mousemoved = forward("mousemoved")
Queue.wheelmoved = forward("wheelmoved")
Queue.press = forward("press")

return LevelupCard
