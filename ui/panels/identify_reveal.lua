-- THE READING: a piece is drawn across the stone and comes back legible.
--
-- The result is already decided when this opens -- the blueprint was chosen when the piece dropped and
-- the level was rolled with it (models/identify.lua), and ui/panels/touchstone.lua has already spent the
-- fee and un-husked the item before a pixel is drawn. What this panel does is WITHHOLD a fact it already
-- holds, which is the whole mechanism the genre runs on. A reveal that rolled at the END of its own
-- animation would be a reveal a player could close and reopen to reroll.
--
-- IT IS THE RIFT'S CROSSING IN ANOTHER MATERIAL (ui/panels/hire_reveal.lua). Four beats, in the same
-- order, for the same reasons -- that reveal tells the player a RANK and this one tells them a LEVEL, and
-- a player who has learned to read one should not have to learn the other from scratch. What separates
-- them is the substance. A rift is air and light, so it breathes and its shape is a ring. This is metal
-- on stone under a lamp, so it is struck: a flat slab, a streak drawn across it, marks stamped in a row.
--
-- FOUR BEATS:
--
--   GATHER  ~0.7s   the lamp comes down and the streak is drawn across the slab. Identical every time,
--                   carrying no information whatever, which is exactly its job: the tell needs something
--                   to differ FROM.
--   TELL    ~0.55s  the level declares itself in TWO channels at once -- the light takes the level's
--                   colour, and the marks strike in one at a time along the slab. Hue alone is a fragile
--                   carrier (it fails on a dim panel, in daylight, and for anyone with a colour vision
--                   deficiency); a COUNT is not. Either channel alone is legible.
--   SURGE   varies  the slab floods. Its length is set by the level -- a +1 is done almost at once, a +8
--                   takes nearly a second -- so duration is information too, and a player learns "this
--                   one is taking a while" in two readings.
--   PIECE           the item itself: icon, true name with its " +n", and its full sheet pinned under it.
--
-- THE GLASS BREAKS ON AN OVERSHOOT. A piece that climbs its whole ladder on a floor deep enough for that
-- to mean something (Identify.isOvershoot) cracks the lamp over the counter and throws it. One branch,
-- and it is the moment worth screenshotting.
--
-- SKIPPABLE, ALWAYS, FROM THE FIRST FRAME. Any key, button or click cuts to the piece -- a player on
-- their fortieth reading is not being taught anything by the light.

local CloseButton = require("ui.close_button")
local ItemTooltip = require("ui.item_tooltip")
local Scale = require("scale")
local Sound = require("models.sound")
local Theme = require("ui.theme")

local Reveal = {}
Reveal.__index = Reveal

local GATHER_T = 0.70
local TELL_T   = 0.55

local SLAB_W, SLAB_H = 300, 96   -- the touchstone itself, centre screen
local MARK_W = 5                 -- one struck mark
local MARK_H = 22
local MARK_GAP = 7
local GRAVITY = 520              -- px/s^2 on the thrown shards

-- WHAT EACH LEVEL LOOKS LIKE, as a ladder rather than a per-level table: the levels run 1..10 and ten
-- authored swatches would be ten chances for two neighbours to be indistinguishable. Cool-and-dim to
-- warm-and-bright, with the top band stepping OUT of the warm family into violet rather than continuing
-- it -- the top of a scale wants to read as a different kind of thing, not as more of the last one.
-- Deliberately the same four waypoints the crossing uses, so the two reveals agree about what "good"
-- looks like in this city.
local BANDS = {
    { 0.360, 0.498, 0.659 }, -- +1     dim steel
    { 0.435, 0.596, 0.835 }, -- +2     steel
    { 0.831, 0.729, 0.447 }, -- +3-4   the house gold
    { 0.878, 0.573, 0.310 }, -- +5-6   hot amber
    { 0.788, 0.639, 0.925 }, -- +7up   violet
}

local function bandFor(level)
    if level <= 1 then return BANDS[1] end
    if level == 2 then return BANDS[2] end
    if level <= 4 then return BANDS[3] end
    if level <= 6 then return BANDS[4] end
    return BANDS[5]
end

local function easeOut(t) return 1 - (1 - t) * (1 - t) end
local function clamp01(t) return t < 0 and 0 or (t > 1 and 1 or t) end

function Reveal.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Reveal)
    self.item = opts.item
    self.level = math.max(1, opts.level or 1)
    self.floor = opts.floor or 1
    self.overshoot = opts.overshoot == true
    self.onClose = opts.onClose
    self.finished = false
    self.t = 0
    self.clock = 0    -- free-running, for the lamp's flicker; never resets so it does not stutter
    self.phase = "gather"
    self.colour = bandFor(self.level)
    self.shards = {}

    -- How many marks have SOUNDED. The drawn count is recomputed from `t` every frame, which is right
    -- for drawing and wrong for firing a cue -- a frame-derived count would ring the chime every frame
    -- the mark was on screen. This is the ratchet that makes each strike happen exactly once.
    self.sounded = 0

    self.cx = Scale.WIDTH / 2
    self.cy = Scale.HEIGHT / 2 - 40

    self.titleFont = Theme.display(26)
    self.hintFont = Theme.body(13)
    self.subFont = Theme.body(13)

    -- THE FIRST BEAT SPEAKS IMMEDIATELY. Fired in the constructor rather than on the first update, so
    -- the cue and the light start together -- an update-driven start is one frame late, which is
    -- inaudible on its own and drifts the whole four-cue sequence.
    Sound.play("stone.read")
    return self
end

-- How many marks have landed by now, during the tell. The FIRST one lands at once and the last lands
-- just before the beat ends -- which is why this counts from one rather than from zero.
--
-- Counting from zero is the obvious form and it is wrong at the bottom of the scale, where it matters
-- most: mark k would land at k/level of the beat, so a +1 reading -- the commonest outcome there is --
-- puts its only mark up at exactly the moment the tell finishes, and the beat whose whole job is to
-- say "one" plays out empty. Drawn AND sounded through here, so the chime and the mark are the same
-- event rather than two that agree most of the time.
function Reveal:marksLanded()
    return math.min(self.level, 1 + math.floor((self.t / TELL_T) * self.level))
end

-- How long the flood takes, set by the level so the pause itself is a tell for a player who is not
-- looking directly at the screen. Bounded at both ends: a +1 must still register as a beat, and a +10
-- must not outstay the moment.
function Reveal:surgeTime()
    return math.min(0.95, 0.26 + self.level * 0.075)
end

-- Build the piece's card. Deferred to the moment the reveal reaches it: ItemTooltip.measure walks the
-- whole item to lay its sheet out, and there is no reason to pay for that behind an animation nobody
-- has finished watching.
function Reveal:openPiece()
    if self.phase == "piece" then return end
    self.phase = "piece"
    self.t = 0
    self.sheet = self.item and ItemTooltip.measure(self.item) or nil
    self.accept = { w = 180, h = 44 }
    self.accept.x = self.cx - self.accept.w / 2
    self.accept.y = Scale.HEIGHT - 96
    self.closeButton = CloseButton.new(Scale.WIDTH - 18, 18)
end

function Reveal:skip()
    if self.phase ~= "piece" then self:openPiece(); return true end
    return false
end

function Reveal:close()
    if self.finished then return end
    self.finished = true
    if self.onClose then self.onClose() end
end

-- Throw the lamp glass. Authored spread rather than a free roll so the break reads the same violent
-- shape every time it happens, which is what makes it recognisable on the second one.
function Reveal:breakGlass()
    for i = 1, 14 do
        local a = (i / 14) * math.pi * 2 + 0.3
        local speed = 260 + (i % 4) * 70
        self.shards[#self.shards + 1] = {
            x = self.cx, y = self.cy,
            vx = math.cos(a) * speed,
            vy = math.sin(a) * speed - 120,
            r = (i % 5) * 0.4,
            spin = (i % 2 == 0) and 5 or -4,
            life = 1.1,
            size = 7 + (i % 3) * 5,
        }
    end
end

function Reveal:update(dt)
    dt = dt or 0
    self.clock = self.clock + dt
    self.t = self.t + dt

    for i = #self.shards, 1, -1 do
        local s = self.shards[i]
        s.life = s.life - dt
        if s.life <= 0 then
            table.remove(self.shards, i)
        else
            s.vy = s.vy + GRAVITY * dt
            s.x = s.x + s.vx * dt
            s.y = s.y + s.vy * dt
            s.r = s.r + s.spin * dt
        end
    end

    if self.phase == "piece" then return end

    -- THE LEVEL, HEARD. One strike per mark as it lands, pitched a step higher each time, so a +6 is a
    -- rising six-note figure and a +1 is a single note. That climb is the tell: the player knows how
    -- good it is before the last mark has finished drawing, which is the same job the marks do visually
    -- and the reason this is one cue transposed rather than several different sounds.
    if self.phase == "tell" then
        local landed = self:marksLanded()
        while self.sounded < landed do
            self.sounded = self.sounded + 1
            Sound.play("stone.mark", { pitch = 1 + (self.sounded - 1) * 0.06 })
        end
    end

    if self.phase == "gather" and self.t >= GATHER_T then
        self.phase = "tell"; self.t = 0
    elseif self.phase == "tell" and self.t >= TELL_T then
        -- Any mark the tell did not get to sound (a short beat, a dropped frame) strikes on the way
        -- out, so the figure is always the full level rather than however much of it fitted.
        while self.sounded < self.level do
            self.sounded = self.sounded + 1
            Sound.play("stone.mark", { pitch = 1 + (self.sounded - 1) * 0.06 })
        end
        self.phase = "surge"; self.t = 0
        Sound.play("stone.reveal")
        -- LAYERED over the flood rather than replacing it: the break is an addition to the payoff, and
        -- a reading that swapped its payoff cue for a rarer one would sound like a different system
        -- rather than like the same one going further than usual.
        if self.overshoot then
            Sound.play("stone.break")
            self:breakGlass()
        end
    elseif self.phase == "surge" and self.t >= self:surgeTime() then
        self:openPiece()
    end
end

-- How far the lamp has come up, how far the level has declared itself, and how far the flood has run.
-- Three numbers rather than one, because the beats overlap in what they move: the streak keeps growing
-- through the tell, and the colour keeps arriving through the flood.
function Reveal:slabState()
    if self.phase == "gather" then
        return easeOut(clamp01(self.t / GATHER_T)), 0, 0
    elseif self.phase == "tell" then
        return 1, clamp01(self.t / TELL_T), 0
    end
    return 1, 1, clamp01(self.t / self:surgeTime())
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

function Reveal:drawShards()
    for _, s in ipairs(self.shards) do
        local a = clamp01(s.life / 1.1)
        love.graphics.push()
        love.graphics.translate(s.x, s.y)
        love.graphics.rotate(s.r)
        Theme.set(self.colour, a * 0.85)
        love.graphics.polygon("fill", -s.size * 0.3, -s.size, s.size * 0.45, 0, -s.size * 0.2, s.size * 0.7)
        love.graphics.pop()
    end
end

function Reveal:drawSlab()
    local core, mix, surge = self:slabState()
    local x = self.cx - SLAB_W / 2
    local y = self.cy - SLAB_H / 2

    -- The bloom behind it, additive so it brightens rather than washing to grey. It reaches further as
    -- the flood runs, which is what makes a high level look like more light and not just a different one.
    -- MORE LAYERS AT LOWER ALPHA, AND A CORNER RADIUS THAT GROWS WITH THE SPREAD. Six hard-edged
    -- rectangles at a workable alpha read as six concentric boxes rather than as light -- the banding is
    -- visible at a glance the moment the flood is bright. Twelve at a third of the alpha, each rounder
    -- than the last, blurs the steps into each other without costing anything.
    local reach = 1 + surge * (0.8 + self.level * 0.16)
    local LAYERS = 12
    love.graphics.setBlendMode("add")
    for i = LAYERS, 1, -1 do
        local t = i / LAYERS
        local a = (0.020 + 0.050 * core + 0.075 * surge) * (1 - t * 0.72) / 2.2
        Theme.set(mix > 0 and self.colour or Theme.accentAmber, a)
        love.graphics.rectangle("fill",
            x - 34 * t * reach, y - 26 * t * reach,
            SLAB_W + 68 * t * reach, SLAB_H + 52 * t * reach, 6 + 26 * t)
    end
    love.graphics.setBlendMode("alpha")

    -- The stone: flat, dark, and squared off. Nothing about it breathes -- the light does the moving,
    -- and a slab that pulsed would read as another rift rather than as a counter.
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, SLAB_W, SLAB_H, 3)
    Theme.set(Theme.frame, 0.9)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", x, y, SLAB_W, SLAB_H, 3)
    love.graphics.setLineWidth(1)

    -- THE STREAK. The mark the piece leaves as it is drawn across, which is the instrument working and
    -- the one thing on screen during the gather. It lengthens with `core` and takes the level's colour
    -- through the tell.
    local pad = 26
    local w = (SLAB_W - pad * 2) * core
    local sy = y + SLAB_H * 0.62
    love.graphics.setBlendMode("add")
    for i = 3, 1, -1 do
        Theme.set(mix > 0 and self.colour or Theme.ink, (0.10 + 0.22 * surge) / i)
        love.graphics.rectangle("fill", x + pad, sy - i * 2, w, 4 + i * 4, 2)
    end
    love.graphics.setBlendMode("alpha")
    Theme.set(mix > 0 and self.colour or Theme.ink, 0.55 + 0.45 * mix)
    love.graphics.rectangle("fill", x + pad, sy - 1.5, w, 3, 1.5)

    -- THE MARKS, struck in a row above the streak, one per level. The count is the half of the tell that
    -- survives a dim screen and a colour vision deficiency, so it is drawn at full contrast whatever the
    -- band's hue is doing.
    if self.phase ~= "gather" then
        local shown = (self.phase == "tell") and self:marksLanded() or self.level
        local total = self.level * MARK_W + math.max(0, self.level - 1) * MARK_GAP
        local mx = self.cx - total / 2
        local my = y + 18
        for i = 1, shown do
            local bx = mx + (i - 1) * (MARK_W + MARK_GAP)
            love.graphics.setBlendMode("add")
            Theme.set(self.colour, 0.5)
            love.graphics.rectangle("fill", bx - 2, my - 3, MARK_W + 4, MARK_H + 6, 2)
            love.graphics.setBlendMode("alpha")
            Theme.set(self.colour, 0.95)
            love.graphics.rectangle("fill", bx, my, MARK_W, MARK_H, 1)
        end
    end
end

function Reveal:drawPiece()
    local item = self.item
    local rise = easeOut(clamp01(self.t / 0.35))

    love.graphics.setFont(self.titleFont)
    Theme.set(self.colour, rise)
    love.graphics.printf(item and item.name or "Named", 0, self.cy - 150, Scale.WIDTH, "center")

    love.graphics.setFont(self.subFont)
    Theme.set(Theme.muted, 0.85 * rise)
    local sub = "Floor " .. self.floor
    if self.overshoot then
        sub = sub .. "  ·  as far as this floor goes"
    end
    love.graphics.printf(sub, 0, self.cy - 116, Scale.WIDTH, "center")

    -- The whole sheet, pinned under the name rather than hung off a cursor: the player is being handed
    -- the piece, not hovering it, so it is placed where they are already looking.
    if self.sheet then
        local w = ItemTooltip.WIDTH
        ItemTooltip.paint(self.sheet, self.cx - w / 2, self.cy - 84, { accent = self.colour })
    end

    local b = self.accept
    Theme.set(Theme.slot, rise)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3)
    Theme.set(self.colour, 0.85 * rise)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 3)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.subFont)
    Theme.set(Theme.ink, rise)
    love.graphics.printf("Take it", b.x, b.y + (b.h - self.subFont:getHeight()) / 2, b.w, "center")
end

function Reveal:draw()
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    if self.phase == "piece" then
        self:drawPiece()
        self:drawShards()
        if self.closeButton then self.closeButton:draw() end
        return
    end

    self:drawSlab()
    self:drawShards()

    love.graphics.setFont(self.hintFont)
    Theme.set(Theme.muted, 0.45)
    love.graphics.printf("Any key to skip", 0, Scale.HEIGHT - 52, Scale.WIDTH, "center")
end

-- ---------------------------------------------------------------------------
-- Input. Everything skips while the beats run; once the piece is up, everything takes it.
-- ---------------------------------------------------------------------------

function Reveal:mousemoved(x, y)
    if self.closeButton then self.closeButton:mousemoved(x, y) end
end

function Reveal:cursorKind(x, y)
    if self.phase ~= "piece" then return "arrow" end
    if self.closeButton and self.closeButton:contains(x, y) then return "hand" end
    local b = self.accept
    if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then return "hand" end
    return "arrow"
end

function Reveal:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self:skip() then return end
    if self.closeButton and self.closeButton:mousepressed(x, y, button) then self:close() return end
    self:close()
end

function Reveal:keypressed(_)
    if self:skip() then return end
    self:close()
end

function Reveal:gamepadpressed(_, _)
    if self:skip() then return end
    self:close()
end

return Reveal
