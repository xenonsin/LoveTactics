-- THE CROSSING: a rift opens in the Rift's card and somebody is on the other side of it.
--
-- The result is already decided when this opens (models/voucher.lua's Voucher.pull ran before a pixel
-- was drawn) and that is deliberate rather than a shortcut -- a reveal that rolls at the END of its own
-- animation is a reveal a player can close to reroll. What this panel does is WITHHOLD a fact it
-- already holds, which is the whole mechanism the genre runs on.
--
-- IT IS DRAWN ON THE RIFT ITSELF. `opts.rect` is the hotspot of the card the rift opens in -- the
-- descent's own stair (data/buildings/the_gate.lua, "The Rift"), which sits dead centre of the plaza --
-- so the light does not float in the middle of the screen unattached to anything. The city has one
-- wound in it and this is that wound being forced open. Without a rect it falls back to screen centre,
-- which is what a caller with no map behind it gets.
--
-- THE SHAPE IS A CIRCLE, AND IT GOT THERE THE LONG WAY. Worth recording, because two other shapes were
-- built and both are worse for reasons that are not obvious until you see them at size:
--
--   a vertical LENS -- two curves meeting at a point top and bottom, widest at the middle, lit from
--   inside, with a silhouette climbing out. It reads unmistakably as anatomy, and reproportioning does
--   not fix it; bilateral symmetry around a bright slit is the problem.
--
--   a jagged FRACTURE -- angular, asymmetric, branched. It solved the read completely and cost the
--   thing the circle has: a rift is a way THROUGH, and a crack is damage. A crack says the wall broke.
--   A ring says something is on the other side.
--
-- So it is a ring closing on a gathering light, which is where this started. What the two detours
-- bought is everything AROUND the shape -- the staging below is theirs and is kept whole.
--
-- AND NOBODY CLIMBS THROUGH IT. There was a silhouette rising out of the tear and it is gone. What the
-- reveal has to deliver is a RANK and a moment; the body itself is read on the card a beat later, at
-- leisure, with its kit and a tooltip on every piece. A figure here spent the card's payoff early and
-- bought nothing the stars do not already say.
--
-- FOUR BEATS:
--
--   GATHER  ~0.7s   light gathers and the ring closes in on it. Identical every time, carrying no
--                   information whatever, which is exactly its job: the tell needs something to differ
--                   FROM. Genshin spends a full second on a comet for the same reason.
--   TELL    ~0.55s  the rank declares itself in TWO channels at once -- the light takes the rank's
--                   colour, and the stars strike in one at a time above the ring. Hue alone is a
--                   fragile carrier (it fails on a dim panel, in daylight, and for anyone with a
--                   colour vision deficiency); a COUNT is not. Either channel alone is legible.
--   SURGE   varies  the core floods. Its length is set by the rank -- a one-star is done almost at
--                   once, a five-star takes nearly a second -- so duration is information too, and a
--                   player learns "this one is taking a while" in two crossings.
--   BODY            ui/panels/recruit.lua in `single` mode: portrait, figures, the kit laid out in the
--                   grid it fights from, a tooltip on every piece.
--
-- THE TOP RANK BREAKS THE RING. A five-star is two percent of pulls -- the rarest thing this system
-- does -- and it used to read as a slightly different hue for half a second. Now the ring fails to
-- hold: it throws shards past the card and the light goes with them. One branch, and it is the moment
-- worth screenshotting.
--
-- SKIPPABLE, ALWAYS, FROM THE FIRST FRAME. Any key, button or click cuts to the body -- a player on
-- their fortieth crossing is not being taught anything by the light. The one exception is the
-- tutorial's staked crossing, opened with `hold = true`, which plays in full because it is the only
-- time the beats are load-bearing (states/hub.lua).

local Glyphs = require("ui.glyphs")
local InputMode = require("input_mode")
local RecruitPanel = require("ui.panels.recruit")
local Scale = require("scale")
local Sound = require("models.sound")
local Theme = require("ui.theme")
local Voucher = require("models.voucher")

local Reveal = {}
Reveal.__index = Reveal

local GATHER_T = 0.70
local TELL_T   = 0.55

-- WHAT EACH RANK LOOKS LIKE. Five steps, and the ladder is cool-and-dim to warm-and-bright, with the
-- fifth stepping OUT of the warm family into violet rather than continuing it -- because five stars is
-- not "more four stars", it is the top of the scale and wants to read as a different kind of thing.
--
-- `hold` is how long the surge takes, and it climbs with the rank for the same reason the hue does: so
-- the pause itself becomes a tell for a player who is not looking directly at the screen.
-- `reach` is how far the light throws.
local RANKS = {
    { color = { 0.360, 0.498, 0.659 }, hold = 0.30, reach = 1.00 }, -- *      dim steel
    { color = { 0.435, 0.596, 0.835 }, hold = 0.42, reach = 1.25 }, -- **     steel
    { color = { 0.831, 0.729, 0.447 }, hold = 0.56, reach = 1.55 }, -- ***    the house gold
    { color = { 0.878, 0.573, 0.310 }, hold = 0.72, reach = 1.95 }, -- ****   hot amber
    { color = { 0.788, 0.639, 0.925 }, hold = 0.95, reach = 2.45 }, -- *****  violet
}
local BONE = { 0.925, 0.894, 0.831 }

function Reveal.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Reveal)
    self.result = opts.result
    self.onClose = opts.onClose
    self.finished = false
    self.t = 0
    self.clock = 0 -- free-running, for the rim's shiver; never resets, so it does not stutter
    self.hold = opts.hold == true
    self.phase = "gather" -- "gather" | "tell" | "surge" | "body"

    local r = self.result or {}
    self.stars = (r.id and Voucher.starsForBody(r.id)) or 1
    self.rank = RANKS[self.stars] or RANKS[1]
    -- THE TOP RANK IS THE EVENT. It used to be an "overshoot" -- a body ranked above the token that
    -- opened the rift -- and tokens have no rank to overshoot any more (models/voucher.lua). What is
    -- left is simpler and reads the same: five stars is the rarest thing the roll does, so five stars is
    -- what breaks the ring.
    self.overshoot = self.stars >= Voucher.MAX_STARS

    local rect = opts.rect
    self.cx = rect and (rect.x + rect.w / 2) or (Scale.WIDTH / 2)
    self.cy = rect and (rect.y + rect.h / 2) or (Scale.HEIGHT / 2)
    -- Sized to sit INSIDE the card it opens in, off the card's short side, so the ring reads as a hole
    -- in that plate rather than as an effect laid over the plaza. The bloom is allowed past the edges;
    -- the ring itself is not.
    self.r = rect and (math.min(rect.w, rect.h) * 0.40) or 110

    self.hintFont = Theme.body(13)
    -- How many rank pips have SOUNDED. The visual count is recomputed from `t` every frame, which is
    -- the right shape for drawing and the wrong one for firing a cue -- a frame-derived count would
    -- ring the chime every frame the pip was on screen. This is the ratchet that makes each strike
    -- happen exactly once.
    self.sounded = 0

    -- THE FIRST BEAT SPEAKS IMMEDIATELY. Fired in the constructor rather than on the first update, so
    -- the cue and the light start together -- an update-driven start is one frame late, which is
    -- inaudible on its own and drifts the whole four-cue sequence.
    Sound.play("rift.open")
    return self
end

-- Build the body panel. Deferred to the moment the reveal reaches it: RecruitPanel measures its whole
-- layout off the character in its constructor, and there is no reason to pay for that behind an
-- animation nobody has finished watching.
function Reveal:openBody()
    if self.phase == "body" then return end
    self.phase = "body"

    local r = self.result or {}
    local title, prompt

    if r.overflow then
        -- THE LADDER WAS ALREADY FINISHED. Say so plainly and say what came back instead, because a
        -- crossing that paid a consolation and did not name it reads as one that paid nothing.
        title = (r.name or "Someone") .. " again"
        prompt = "Their relic is already as far as it goes. The token comes back one rank lower."
    elseif r.dupe then
        -- THE BOND, as a transition rather than an addition -- the house rule for a figure that is
        -- always on screen: the player wants the two ends, not the delta.
        local was = math.max(0, (r.relicLevel or 1) - 1)
        title = (r.name or "Someone") .. " again"
        prompt = ((r.relic and r.relic.name) or "Their relic") ..
            "  " .. was .. " -> " .. (r.relicLevel or 1)
        if (r.bond or 0) == 1 then
            prompt = prompt .. "     ...and they come back stronger than they left."
        end
    else
        title = (r.name or "Someone") .. " comes through"
        local WORD = { "One star", "Two stars", "Three stars", "Four stars", "Five stars" }
        prompt = (WORD[self.stars] or "One star")
        if r.rigged then
            -- The sponsor's opening crossing is not a body the ranks dealt, and claiming otherwise
            -- would teach the player a rule the game does not follow (models/voucher.lua).
            prompt = "The sponsor's word, made good."
        elseif self.overshoot then
            prompt = prompt .. "  ...and two crossings in a hundred go this deep."
        end
    end

    self.body = RecruitPanel.new({
        title = title,
        prompt = prompt,
        char = r.char,
        single = true,
        acceptLabel = r.dupe and "Good" or "Welcome",
        onAccept = function()
            self.finished = true
            if self.onClose then self.onClose() end
        end,
    })
end

function Reveal:skip()
    if self.hold then return false end
    if self.phase ~= "body" then self:openBody() return true end
    return false
end

function Reveal:surgeTime() return self.rank.hold end

function Reveal:update(dt)
    self.clock = self.clock + dt
    if self.phase == "body" then
        if self.body and self.body.update then self.body:update(dt) end
        return
    end
    self.t = self.t + dt

    -- THE RANK, HEARD. One chime per pip as it lands, pitched a step higher each time, so a five-star
    -- is a rising five-note figure and a one-star is a single note. That climb is the tell -- the
    -- player knows how good it is before the last pip has finished drawing, which is the same job the
    -- pips do visually and the reason this is one cue transposed rather than five different sounds.
    --
    -- Driven off the same fraction drawStars reads, but ratcheted through `self.sounded`: the drawn
    -- count is recomputed every frame and would otherwise ring the chime every frame.
    if self.phase == "tell" then
        local landed = math.min(self.stars, math.floor((self.t / TELL_T) * self.stars))
        while self.sounded < landed do
            self.sounded = self.sounded + 1
            Sound.play("rift.star", { pitch = 1 + (self.sounded - 1) * 0.06 })
        end
    end

    if self.phase == "gather" and self.t >= GATHER_T then
        self.phase = "tell"; self.t = 0
    elseif self.phase == "tell" and self.t >= TELL_T then
        -- Any pip the tell did not get to sound (a short beat, a dropped frame) rings on the way out,
        -- so the figure is always the full rank rather than however much of it fitted.
        while self.sounded < self.stars do
            self.sounded = self.sounded + 1
            Sound.play("rift.star", { pitch = 1 + (self.sounded - 1) * 0.06 })
        end
        self.phase = "surge"; self.t = 0
        Sound.play("rift.surge")
        -- LAYERED over the surge rather than replacing it: the break is an addition to the payoff, and
        -- a crossing that swapped its payoff cue for a rarer one would sound like a different system
        -- rather than like the same one going further than usual.
        if self.overshoot then Sound.play("rift.overshoot") end
    elseif self.phase == "surge" and self.t >= self:surgeTime() then
        self:openBody()
    end
end

-- ---------------------------------------------------------------------------
-- The ring
-- ---------------------------------------------------------------------------

-- How far the light has come up, how far the rank has declared itself, and how far the surge has run.
-- Three numbers rather than one, because the beats overlap in what they move: the core keeps growing
-- through the tell, and the colour keeps arriving through the surge.
function Reveal:ringState()
    if self.phase == "gather" then
        local p = math.min(1, self.t / GATHER_T)
        return 1 - (1 - p) * (1 - p), 0, 0 -- core, mix (rank colour), surge
    elseif self.phase == "tell" then
        local p = math.min(1, self.t / TELL_T)
        return 1, p, 0
    else
        return 1, 1, math.min(1, self.t / self:surgeTime())
    end
end

-- The rim, as a closed loop of points with a slight live wobble. NOT a perfect circle: a mathematically
-- exact ring reads as a summoning diagram drawn on the floor, and this is a hole torn in the air. The
-- wobble is a sine of angle AND time rather than noise, so the edge lives without flickering -- a jitter
-- re-rolled per frame reads as static, and static reads as a bug.
function Reveal:rimPoints(radius, wobble)
    local pts, N = {}, 64
    for i = 0, N - 1 do
        local a = (i / N) * math.pi * 2
        local w = 1 + (wobble or 0) * (0.30 * math.sin(a * 3 + self.clock * 1.7)
                                     + 0.26 * math.sin(a * 7 - self.clock * 2.3)
                                     + 0.18 * math.sin(a * 11 + self.clock * 1.1))
        pts[#pts + 1] = self.cx + math.cos(a) * radius * w
        pts[#pts + 1] = self.cy + math.sin(a) * radius * w
    end
    return pts
end

function Reveal:drawRing()
    local core, mix, surge = self:ringState()
    local c = {
        BONE[1] + (self.rank.color[1] - BONE[1]) * mix,
        BONE[2] + (self.rank.color[2] - BONE[2]) * mix,
        BONE[3] + (self.rank.color[3] - BONE[3]) * mix,
    }

    local bloom = 1 + (self.rank.reach - 1) * mix
    local radius = self.r * (0.34 + 0.66 * core) * (1 + 0.10 * surge)

    -- THE LIGHT, additive and in many thin layers. Alpha-blended discs of a pale colour over a
    -- near-black ground average toward grey however many you stack -- the first cut of this drew a flat
    -- olive coin. Adding only ever brightens, so the middle blows out and the rim keeps the rank's hue,
    -- which is what a light actually does. Two dozen layers puts the banding below what the eye
    -- resolves; six equal discs read as six concentric rings.
    local LAYERS = 24
    love.graphics.setBlendMode("add")
    for i = LAYERS, 1, -1 do
        local t = i / LAYERS
        love.graphics.setColor(c[1], c[2], c[3],
            (0.020 + 0.100 * mix + 0.030 * surge) * (1 - t * 0.85))
        love.graphics.circle("fill", self.cx, self.cy, radius * bloom * (0.12 + t * 1.05), 48)
    end
    love.graphics.setBlendMode("alpha")

    -- THE RIM, CLOSING IN. The disc grows while the ring shrinks toward it -- two motions travelling
    -- toward each other, which reads as something ARRIVING rather than as something merely getting
    -- bigger. It is also the only hard edge on screen, so it is what the eye tracks.
    local ringR = radius * (2.5 - 1.5 * core)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(c[1], c[2], c[3], 0.55 + 0.40 * mix)
    love.graphics.polygon("line", self:rimPoints(ringR, 0.035 + 0.020 * mix))

    -- A second, fainter rim just outside it once the rank has spoken: depth, and one more thing for the
    -- surge to push on.
    if mix > 0 then
        love.graphics.setLineWidth(1)
        love.graphics.setColor(c[1], c[2], c[3], 0.20 * mix * (1 - surge * 0.5))
        love.graphics.polygon("line", self:rimPoints(ringR * (1.16 + 0.10 * surge), 0.05))
    end
    love.graphics.setLineWidth(1)

    -- AN OVERSHOOT BREAKS THE RING. Shards throw outward past the card and the light goes with them --
    -- the one branch in this file, and the only place the animation leaves the rift's own rect.
    if self.overshoot and surge > 0 then
        local q = surge
        love.graphics.setBlendMode("add")
        love.graphics.setLineWidth(2)
        for s = 0, 11 do
            local a = (s / 12) * math.pi * 2 + 0.26
            local from = ringR * (1 + q * 0.5)
            local to = ringR * (1.2 + q * 2.6)
            love.graphics.setColor(c[1], c[2], c[3], 0.32 * (1 - q))
            love.graphics.line(self.cx + math.cos(a) * from, self.cy + math.sin(a) * from,
                               self.cx + math.cos(a) * to,   self.cy + math.sin(a) * to)
        end
        love.graphics.setLineWidth(3 * (1 - q) + 0.5)
        love.graphics.setColor(c[1], c[2], c[3], 0.45 * (1 - q))
        love.graphics.polygon("line", self:rimPoints(ringR * (1.3 + q * 2.2), 0.08))
        love.graphics.setLineWidth(1)
        love.graphics.setBlendMode("alpha")
    end
end

-- THE RANK, STRIKING IN ONE AT A TIME. The second channel of the tell, and the one that survives a dim
-- panel and a colour vision deficiency -- a count is not a hue. Each pip lands with a short overshoot
-- so it reads as struck rather than faded up.
function Reveal:drawStars()
    if self.phase == "gather" then return end
    local shown = (self.phase == "tell") and (self.t / TELL_T) * self.stars or self.stars

    local pip = 17
    local gap = pip * 0.34
    local total = self.stars * pip + (self.stars - 1) * gap
    local x = self.cx - total / 2
    local y = self.cy - self.r * 1.62 - pip

    for i = 1, self.stars do
        local born = math.min(1, math.max(0, shown - (i - 1)))
        if born > 0 then
            -- Overshoot then settle: 1.55x at birth, 1.0 by the time it is a quarter old.
            local pop = born < 0.28 and (1.55 - 0.55 * (born / 0.28)) or 1
            local s = pip * pop
            local off = (s - pip) / 2
            Glyphs.star(x + (i - 1) * (pip + gap) - off, y - off, s, s,
                self.rank.color[1], self.rank.color[2], self.rank.color[3], math.min(1, born * 1.6))
        end
    end
end

function Reveal:draw()
    if self.phase == "body" then
        if self.body then self.body:draw() end
        return
    end

    -- Darker than an ordinary modal's 0.6 scrim. Nothing about the city is information during a
    -- crossing, and at 0.6 the building labels read straight through the light.
    love.graphics.setColor(0, 0, 0, 0.94)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    self:drawRing()
    self:drawStars()

    -- NO CAPTION. There was a line under this ("The hall answers") and it is gone: the stars say what
    -- it said, the ring says where, and a sentence explaining an animation is a sentence admitting the
    -- animation did not land.
    if not self.hold then
        love.graphics.setFont(self.hintFont)
        Theme.set(Theme.muted, 0.40)
        love.graphics.printf(InputMode.isGamepad() and "Any button to skip" or "Any key to skip",
            0, Scale.HEIGHT - 44, Scale.WIDTH, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------
--
-- Everything forwards to the body panel once it is up, and skips the ring before that. Written out per
-- callback rather than through a metatable forward, because the two phases answer the same events
-- differently and a forward that guessed would be the bug.

function Reveal:mousemoved(x, y)
    if self.phase == "body" and self.body then self.body:mousemoved(x, y) end
end

function Reveal:cursorKind(x, y)
    if self.phase == "body" and self.body then return self.body:cursorKind(x, y) end
    return "arrow"
end

function Reveal:mousepressed(x, y, button)
    if self:skip() then return end
    if self.phase == "body" and self.body then self.body:mousepressed(x, y, button) end
end

function Reveal:keypressed(key)
    if self:skip() then return end
    if self.phase == "body" and self.body then self.body:keypressed(key) end
end

function Reveal:gamepadpressed(joystick, button)
    if self:skip() then return end
    if self.phase == "body" and self.body then self.body:gamepadpressed(joystick, button) end
end

return Reveal
