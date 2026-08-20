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
-- FIVE BEATS, AND THE MIDDLE ONE IS THE PLAYER'S:
--
--   GATHER  ~0.7s   light gathers and the ring closes in on it. Identical every time, carrying no
--                   information whatever, which is exactly its job: the tell needs something to differ
--                   FROM. Genshin spends a full second on a comet for the same reason.
--   GRIP    waits   the light holds, breathing, and does nothing until it is TAKEN HOLD OF and drawn
--                   up. See below -- this is the beat the whole thing turns on.
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
-- THE PLAYER PULLS IT THROUGH. Every beat here used to be on a timer, which made the crossing something
-- that HAPPENED AT the player: press the plate, watch four seconds of light, read a card. The result is
-- decided before the first frame either way -- that does not change and must not -- so what the middle
-- beat buys is not agency over the outcome, it is the player's hands on the moment the outcome arrives.
-- Take hold of the light and draw it up. It is heavy: it climbs less far than the hand does, and let go
-- short of the top and it sinks back into the tear. Nothing is lost by letting go and nothing is won by
-- being quick -- which is the point. The tell fires when the light clears, so the rank lands on a
-- gesture the player is in the middle of making rather than on a frame counter.
--
-- Three inputs, one gesture (the project standard): drag it with the mouse, or hold Up on a keyboard or
-- a pad. The held direction is POLLED in update rather than driven off keypressed, because what this
-- beat asks for is a hold and a keypress is an instant. The keyboard and pad pull is timed instead of
-- measured, since a held direction covers no distance.
--
-- AND THE CARD COMES UP INSIDE THE RING. The reveal used to hand the whole screen to the body panel and
-- the light simply stopped existing -- the tear you had just hauled somebody out of vanished at the
-- instant it paid off. Now the ring keeps opening: it widens past the card, dims to a steady glow, and
-- the card rises into the middle of it (ui/panels/recruit.lua draws no scrim of its own when the
-- crossing owns the ground). The hole is still open behind the person who came through it.
--
-- THE TOP RANK BREAKS THE RING. A five-star is two percent of pulls -- the rarest thing this system
-- does -- and it used to read as a slightly different hue for half a second. Now the ring fails to
-- hold: it throws shards past the card and the light goes with them. One branch, and it is the moment
-- worth screenshotting.
--
-- SKIPPABLE, ALWAYS, FROM THE FIRST FRAME. Any key, button or click cuts to the body -- a player on
-- their fortieth crossing is not being taught anything by the light. The two things that are NOT the
-- skip are the pull itself (Up, and a press on the ball) for the obvious reason: a gesture whose own
-- input cancels it is not a gesture. The one exception is the tutorial's staked crossing, opened with
-- `hold = true`, which plays in full because it is the only time the beats are load-bearing -- and
-- which is now where the pull is TAUGHT, since it is the one crossing with no way past it
-- (states/hub.lua). tests/crossing_pull_spec.lua pins all of it.

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

-- THE PULL, IN NUMBERS.
--
-- `PULL_SPAN` is how far the hand travels to draw the light out, in logical pixels -- a fifth of the
-- screen's height, which is a deliberate haul rather than a flick. `PULL_LIFT` is how far the light
-- itself climbs at the top of that haul, and it is deliberately SHORTER: the light lags the hand, which
-- is the only way a thing being dragged reads as heavy.
local PULL_SPAN = 150
local PULL_LIFT = 96
-- A keyboard or a pad holds a direction and covers no distance, so their pull is timed instead. Set so
-- the two cost about the same effort rather than so the numbers match.
local PULL_HOLD_T = 0.80
-- Let go short of the top and it sinks, at this much of the pull per second. Faster than it rose,
-- because whatever is holding it down is stronger than the hand.
local SINK_RATE = 1.30

-- THE FINISH. The ring opens to frame the card (`FRAME_R` is sized to stay on screen at 720 tall, so
-- the arcs above and below the card are the ones that read), and the card rises the last few pixels
-- into it. The rise is INTEGER pixels of translation and nothing else -- no scale, because scaling a
-- panel scales its text and scaled text is blurred text.
local FRAME_T = 0.40
local FRAME_R = Scale.HEIGHT * 0.46
local RISE_T = 0.22
local RISE_H = 18

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
    self.phase = "gather" -- "gather" | "grip" | "tell" | "surge" | "body"
    -- How far the light has come up, 0..1. Kept apart from `t` because it keeps climbing through the
    -- grip: a player who grabs the ball at half a second does not get a light that snaps to full.
    self.gather = 0
    self.pull = 0     -- 0..1, how far the player has drawn it out of the tear
    self.grab = nil   -- the mouse's hold: { y = where the press landed, pull = the pull it started at }
    self.bodyT = 0    -- since the card opened, for the ring's widening and the card's rise

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
    -- The grip's ask, one step up from a hint: it is the only thing on the screen being asked for.
    self.promptFont = Theme.body(16)
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
        -- THE CROSSING OWNS THE GROUND. This panel lays a 0.6 scrim of its own wherever it is opened
        -- from a floor stop; here it would be a second veil over the one already down, and the ring
        -- behind the card would be dimmed by the very thing it is meant to be behind.
        scrim = false,
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

-- ---------------------------------------------------------------------------
-- The pull
-- ---------------------------------------------------------------------------

-- Is the pull being HELD on a keyboard or a pad? Polled rather than read off keypressed, because this
-- beat asks for a hold and a keypress is an instant. The same three sources ui/overworld_map.lua walks
-- -- keys, d-pad, left stick -- so a player who steers with the stick pulls with it too.
function Reveal:pullHeld()
    if love.keyboard and love.keyboard.isDown and love.keyboard.isDown("up", "w") then return true end
    if love.joystick and love.joystick.getJoysticks then
        for _, joy in ipairs(love.joystick.getJoysticks()) do
            if joy:isGamepad() then
                if joy:isGamepadDown("dpup") then return true end
                if (joy:getGamepadAxis("lefty") or 0) <= -0.45 then return true end
            end
        end
    end
    return false
end

-- How far the light has actually climbed, in pixels. Smoothstepped off the pull rather than linear, so
-- it comes away from the tear slowly and then follows.
function Reveal:lift()
    local p = self.pull
    return PULL_LIFT * p * p * (3 - 2 * p)
end

-- The grab target: the ball, and a good deal of air around it. Generous on purpose -- a player told to
-- take hold of a light aims at the light, not at a hitbox, and a press that misses SKIPS the crossing.
function Reveal:overBall(x, y)
    if self.phase ~= "gather" and self.phase ~= "grip" then return false end
    local dx, dy = x - self.cx, y - (self.cy - self:lift())
    local grab = math.max(72, self.r * 1.55)
    return dx * dx + dy * dy <= grab * grab
end

-- Taking hold ENDS THE GATHER rather than waiting it out: a player quick enough to grab the light at
-- half a second has already understood the beat, and holding them to the rest of a timer they have
-- visibly outrun is the animation asserting itself over them.
function Reveal:takeHold(y)
    if self.phase == "gather" then self.phase = "grip"; self.t = 0 end
    if y then self.grab = { y = y, pull = self.pull } end
end

function Reveal:commitPull()
    self.grab = nil
    self.pull = 1
    self.gather = 1
    self.phase = "tell"
    self.t = 0
end

function Reveal:updatePull(dt)
    -- While the mouse has it, the pull is wherever the hand is (mousemoved sets it) and nothing here
    -- touches it. Let go, or never take hold, and it answers the held direction or sinks.
    if not self.grab then
        if self:pullHeld() then
            self.pull = math.min(1, self.pull + dt / PULL_HOLD_T)
        else
            self.pull = math.max(0, self.pull - dt * SINK_RATE)
        end
    end
    if self.pull >= 1 then self:commitPull() end
end

function Reveal:update(dt)
    self.clock = self.clock + dt
    if self.phase == "body" then
        self.bodyT = self.bodyT + dt
        if self.body and self.body.update then self.body:update(dt) end
        return
    end
    self.t = self.t + dt
    if self.phase == "gather" or self.phase == "grip" then
        self.gather = math.min(1, self.gather + dt / GATHER_T)
    end

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
        -- The light is up and the timers are done. Nothing else moves until the player moves it.
        self.phase = "grip"; self.t = 0
    elseif self.phase == "grip" then
        self:updatePull(dt)
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
    if self.phase == "gather" or self.phase == "grip" then
        local p = self.gather
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
-- Takes its centre rather than reading self.cx/cy, because the ring no longer stays where the tear is:
-- it rides up with the pull and then walks to the card's middle to frame it.
-- `stretch` pulls the UPPER half of the loop up by that many pixels and leaves the lower half exactly
-- where it was. It is not a scale, and it must not become one: a ring stretched evenly is an ellipse,
-- and a tall symmetrical ellipse lit from inside is the vertical lens this shape was designed away from
-- (see the header). What a one-sided pull gives instead is a round hole with a dome drawn out of the
-- top of it -- asymmetric, which is the property that killed the anatomy read the first time.
function Reveal:rimPoints(cx, cy, rx, ry, wobble, stretch)
    local pts, N = {}, 64
    for i = 0, N - 1 do
        local a = (i / N) * math.pi * 2
        local w = 1 + (wobble or 0) * (0.30 * math.sin(a * 3 + self.clock * 1.7)
                                     + 0.26 * math.sin(a * 7 - self.clock * 2.3)
                                     + 0.18 * math.sin(a * 11 + self.clock * 1.1))
        local up = math.max(0, -math.sin(a)) -- 0 along the waist, 1 at the top of the loop
        local pinch = 1 - 0.22 * up * ((stretch or 0) / PULL_LIFT)
        pts[#pts + 1] = cx + math.cos(a) * rx * w * pinch
        pts[#pts + 1] = cy + math.sin(a) * ry * w - up ^ 1.4 * (stretch or 0)
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
    -- A BREATH WHILE IT WAITS, AND A BRIGHTER ONE. Only during the grip: a light that sits perfectly
    -- still reads as a still image, and this beat has no timer to prove otherwise. The lift is what the
    -- extra brightness is for -- at the gather's own alpha the ball is a smudge inside a ring, and the
    -- screen has just asked the player to take hold of it. A thing you are told to grab has to look
    -- like a thing worth grabbing.
    local waiting = 0
    if self.phase == "grip" then
        waiting = 0.035 * (1 - self.pull * 0.4)
        if not self.grab then radius = radius * (1 + 0.035 * math.sin(self.clock * 2.6)) end
    end

    -- THE RIM, CLOSING IN. The disc grows while the ring shrinks toward it -- two motions travelling
    -- toward each other, which reads as something ARRIVING rather than as something merely getting
    -- bigger. It is also the only hard edge on screen, so it is what the eye tracks.
    local ringR = radius * (2.5 - 1.5 * core)

    -- THE TEAR DOES NOT MOVE; IT IS DRAWN OUT AT THE TOP.
    --
    -- The first cut of the pull moved the whole ring up the screen, and it read as a lamp being carried
    -- rather than as anything being drawn out of anywhere: the hole travelled with the thing that was
    -- supposed to be leaving it. So the tear stays exactly where it was torn -- it is a hole in a card,
    -- it has nowhere to go -- and what follows the hand is its upper edge and the light inside it. One
    -- shape doing two things, which is what keeps this from needing a second glowing object to explain
    -- the gap between them.
    local L = self:lift()
    local cx, cy = self.cx, self.cy - L * 0.86 -- the light, just under the drawn-out tip
    local ringCy = self.cy
    local rx, ry = ringR, ringR
    local stretch = L
    local dim = 1

    -- AND THEN IT OPENS THE REST OF THE WAY. Once the card is up the ring keeps widening -- past the
    -- card on both sides, back down to the middle of the screen the card is centred on, round again,
    -- and dimmer, because a hole that has finished delivering is not still flooding. The eased term is
    -- a cubic so the widening decelerates hard: it arrives at the frame rather than sliding to a halt.
    if self.phase == "body" then
        local f = math.min(1, self.bodyT / FRAME_T)
        f = 1 - (1 - f) * (1 - f) * (1 - f)
        local mid = Scale.HEIGHT / 2
        cy = cy + (mid - cy) * f
        ringCy = ringCy + (mid - ringCy) * f
        rx = rx + (FRAME_R - rx) * f
        ry = ry + (FRAME_R - ry) * f
        radius = radius + (FRAME_R * 0.70 - radius) * f
        stretch = stretch * (1 - f) -- the tear relaxes back to a circle as it opens
        dim = 1 - 0.55 * f
    end

    -- THE LIGHT, additive and in many thin layers. Alpha-blended discs of a pale colour over a
    -- near-black ground average toward grey however many you stack -- the first cut of this drew a flat
    -- olive coin. Adding only ever brightens, so the middle blows out and the rim keeps the rank's hue,
    -- which is what a light actually does. Two dozen layers puts the banding below what the eye
    -- resolves; six equal discs read as six concentric rings.
    -- Two dozen is enough at the size the tear opens to and not at the size it FINISHES at: the same
    -- count spread over a bloom five times as wide puts a step every twenty pixels, and the corners of
    -- the framed card fill up with visible rings. So the count follows the radius and the alpha is
    -- normalised back to what 24 layers gave, which keeps the light the same brightness either way.
    local LAYERS = math.max(24, math.min(64, math.floor(radius * bloom / 12)))
    local norm = 24 / LAYERS
    love.graphics.setBlendMode("add")
    for i = LAYERS, 1, -1 do
        local t = i / LAYERS
        -- The waiting light is added to the INNER layers only ((1-t) squared), which is the difference
        -- between a bright core and a brighter wash: spread evenly it lifts the whole stack far enough
        -- that the two dozen discs stop hiding each other and the eye starts counting rings.
        love.graphics.setColor(c[1], c[2], c[3],
            (((0.020 + 0.100 * mix + 0.030 * surge) * dim * (1 - t * 0.85))
            + waiting * (1 - t) ^ 2 * 2.2) * norm)
        love.graphics.circle("fill", cx, cy, radius * bloom * (0.12 + t * 1.05), 48)
    end
    love.graphics.setBlendMode("alpha")

    love.graphics.setLineWidth(2)
    love.graphics.setColor(c[1], c[2], c[3], (0.55 + 0.40 * mix) * dim)
    love.graphics.polygon("line", self:rimPoints(cx, ringCy, rx, ry, 0.035 + 0.020 * mix, stretch))

    -- A second, fainter rim just outside it once the rank has spoken: depth, and one more thing for the
    -- surge to push on.
    if mix > 0 then
        local out = 1.16 + 0.10 * surge
        love.graphics.setLineWidth(1)
        love.graphics.setColor(c[1], c[2], c[3], 0.20 * mix * (1 - surge * 0.5) * dim)
        love.graphics.polygon("line", self:rimPoints(cx, ringCy, rx * out, ry * out, 0.05, stretch * out))
    end
    love.graphics.setLineWidth(1)

    -- AN OVERSHOOT BREAKS THE RING. Shards throw outward past the card and the light goes with them --
    -- the one branch in this file, and the only place the animation leaves the rift's own rect.
    if self.overshoot and surge > 0 and self.phase ~= "body" then
        local q = surge
        love.graphics.setBlendMode("add")
        love.graphics.setLineWidth(2)
        for s = 0, 11 do
            local a = (s / 12) * math.pi * 2 + 0.26
            local fx, fy = rx * (1 + q * 0.5), ry * (1 + q * 0.5)
            local tx, ty = rx * (1.2 + q * 2.6), ry * (1.2 + q * 2.6)
            -- Off the rim as it actually stands, drawn-out top included, or the upper shards would
            -- start inside the shape they are supposed to be leaving.
            local dy = -(math.max(0, -math.sin(a)) ^ 1.4) * stretch
            love.graphics.setColor(c[1], c[2], c[3], 0.32 * (1 - q))
            love.graphics.line(cx + math.cos(a) * fx, ringCy + math.sin(a) * fy + dy,
                               cx + math.cos(a) * tx, ringCy + math.sin(a) * ty + dy)
        end
        love.graphics.setLineWidth(3 * (1 - q) + 0.5)
        love.graphics.setColor(c[1], c[2], c[3], 0.45 * (1 - q))
        local blown = 1.3 + q * 2.2
        love.graphics.polygon("line", self:rimPoints(cx, ringCy, rx * blown, ry * blown, 0.08, stretch))
        love.graphics.setLineWidth(1)
        love.graphics.setBlendMode("alpha")
    end
end

-- THE RANK, STRIKING IN ONE AT A TIME. The second channel of the tell, and the one that survives a dim
-- panel and a colour vision deficiency -- a count is not a hue. Each pip lands with a short overshoot
-- so it reads as struck rather than faded up.
function Reveal:drawStars()
    if self.phase == "gather" or self.phase == "grip" then return end
    local shown = (self.phase == "tell") and (self.t / TELL_T) * self.stars or self.stars

    local pip = 17
    local gap = pip * 0.34
    local total = self.stars * pip + (self.stars - 1) * gap
    local x = self.cx - total / 2
    -- Over the LIGHT, not over the tear: the rank belongs to the thing that was pulled out, and pips
    -- left behind at the hole would read as belonging to the hole.
    local y = self.cy - self:lift() - self.r * 1.62 - pip

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

-- WHICH WAY. Three chevrons standing off the top of the tear, each rising and fading and then starting
-- again from the bottom of the run -- the direction of the gesture, said in the only channel that can
-- say a direction without naming a key. The sentence below the tear names the input; this names the
-- way, and between them a player who reads neither still sees something pointing up and something
-- moving up. They go out as the pull comes in: an instruction that is still on screen while the player
-- is obeying it is an instruction that thinks they are not.
function Reveal:drawGripCue()
    if self.phase ~= "grip" then return end
    local fade = math.min(1, self.t / 0.35) * (1 - self.pull)
    if fade <= 0.01 then return end

    local top = self.cy - self:lift() - self.r - 20
    local w, h = 13, 8
    love.graphics.setLineWidth(2.5)
    for i = 0, 2 do
        -- Staggered thirds of one loop, so the three of them read as one thing travelling rather than
        -- as three things blinking.
        local p = ((self.clock * 0.9 + i / 3) % 1)
        local y = top - p * 40
        love.graphics.setColor(BONE[1], BONE[2], BONE[3], 0.9 * fade * math.sin(p * math.pi))
        love.graphics.line(self.cx - w, y + h, self.cx, y, self.cx + w, y + h)
    end
    love.graphics.setLineWidth(1)
end

-- THE ONLY TEXT IN HERE, and it is not a caption. There was a caption once ("The hall answers") and it
-- is gone for the reason a caption always goes: a sentence explaining an animation is a sentence
-- admitting the animation did not land. This is different in kind -- it is an ASK, and an act nobody
-- has been told about is an act that does not happen. It fades out as the pull comes up, so the instant
-- the player is doing it the instruction stops being on screen.
function Reveal:drawGripPrompt()
    if self.phase ~= "grip" then return end
    local fade = math.min(1, self.t / 0.35) * (1 - self.pull)
    if fade <= 0.01 then return end

    -- ONE LINE, AND IT NAMES THE ACT RATHER THAN THE CONTROL. In the fiction's own words: the wisp on a
    -- floor is a HEROIC SPIRIT (data/encounters/encounter_heroic_spirit.lua) and this is one being
    -- hauled up out of where they went, which is what a crossing IS.
    --
    -- A second, smaller line under it spelled the gesture out per input ("Take hold of it and draw it
    -- up" against "Hold Up to draw it out") and it is gone on the author's call. What it was competing
    -- with is the chevrons, which say the same thing in the channel that says it faster -- three marks
    -- pointing up and travelling up, over a light the player is standing in front of. A control legend
    -- under a one-gesture screen reads as a manual for a room that has one door in it.
    love.graphics.setFont(self.promptFont)
    -- Ink rather than the muted grey every other hint in here wears: the line at the bottom of the
    -- screen is an aside a player may ignore, and this one is the screen waiting to be answered.
    Theme.set(Theme.ink, 0.92 * fade)
    love.graphics.printf("Pull the heroic spirit from the void",
        0, self.cy + self.r * 1.9, Scale.WIDTH, "center")
end

function Reveal:riseOffset()
    if self.phase ~= "body" then return 0 end
    local p = math.min(1, self.bodyT / RISE_T)
    return math.floor(RISE_H * (1 - p) * (1 - p) + 0.5)
end

function Reveal:draw()
    -- Darker than an ordinary modal's 0.6 scrim. Nothing about the city is information during a
    -- crossing, and at 0.6 the building labels read straight through the light. It stays down under the
    -- card too, which is why the card draws none of its own (see `scrim = false` in openBody).
    love.graphics.setColor(0, 0, 0, 0.94)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    self:drawRing()

    if self.phase == "body" then
        -- The card comes up the last few pixels into the ring. Translation only, and to whole pixels:
        -- a scaled panel is a panel with blurred text in it.
        local off = self:riseOffset()
        love.graphics.push()
        love.graphics.translate(0, off)
        if self.body then self.body:draw() end
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1)
        return
    end

    self:drawStars()
    self:drawGripCue()
    self:drawGripPrompt()

    if not self.hold then
        -- "Any key" stops being true the moment Up means something, and a hint the player can catch
        -- lying is worse than no hint.
        local skip
        if self.phase == "grip" then
            -- The mouse's version says WHERE, because that is what changed for it: a press on the light
            -- is the pull and only a press off it is the way past.
            if InputMode.isGamepad() then skip = "Any other button skips"
            elseif InputMode.isMouse() then skip = "Click off the light to skip"
            else skip = "Any other key skips" end
        else
            skip = InputMode.isGamepad() and "Any button to skip" or "Any key to skip"
        end
        love.graphics.setFont(self.hintFont)
        Theme.set(Theme.muted, 0.40)
        love.graphics.printf(skip, 0, Scale.HEIGHT - 44, Scale.WIDTH, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

-- ---- input -------------------------------------------------------------------
--
-- Everything forwards to the body panel once it is up, and skips the ring before that. Written out per
-- callback rather than through a metatable forward, because the two phases answer the same events
-- differently and a forward that guessed would be the bug.

-- The card is drawn a few pixels low while it rises, so every pointer event handed to it is moved the
-- same few pixels the other way. Cheaper and more honest than freezing input for a fifth of a second:
-- a button that is drawn where it can be clicked is a button that can be clicked.
function Reveal:mousemoved(x, y)
    if self.phase == "body" then
        if self.body then self.body:mousemoved(x, y - self:riseOffset()) end
        return
    end
    -- The hand has it: the pull is wherever the hand has got to, measured from where it took hold.
    if self.grab then
        self.pull = math.max(0, math.min(1, self.grab.pull + (self.grab.y - y) / PULL_SPAN))
        if self.pull >= 1 then self:commitPull() end
    end
end

function Reveal:cursorKind(x, y)
    if self.phase == "body" and self.body then return self.body:cursorKind(x, y - self:riseOffset()) end
    if self.grab or self:overBall(x, y) then return "hand" end
    return "arrow"
end

-- THE BALL ANSWERS A PRESS BEFORE THE SKIP DOES. Anywhere else on the screen still cuts to the card --
-- a player on their fortieth crossing is not being taught anything by the light -- but a press ON the
-- thing the screen has just asked them to take hold of can only mean one thing.
function Reveal:mousepressed(x, y, button)
    if self.phase == "body" then
        if self.body then self.body:mousepressed(x, y - self:riseOffset(), button) end
        return
    end
    if self:overBall(x, y) then self:takeHold(y) return end
    self:skip()
end

function Reveal:mousereleased(x, y, button)
    if self.phase == "body" then
        if self.body and self.body.mousereleased then
            self.body:mousereleased(x, y - self:riseOffset(), button)
        end
        return
    end
    -- Let go short of the top and updatePull takes it from here: it sinks back into the tear.
    self.grab = nil
end

function Reveal:keypressed(key)
    if self.phase == "body" then
        if self.body then self.body:keypressed(key) end
        return
    end
    -- Up is the pull, so Up is not the skip. The press only opens the beat -- what actually raises the
    -- light is the HOLD, polled in update.
    if key == "up" or key == "w" then self:takeHold() return end
    self:skip()
end

function Reveal:gamepadpressed(joystick, button)
    if self.phase == "body" then
        if self.body then self.body:gamepadpressed(joystick, button) end
        return
    end
    if button == "dpup" then self:takeHold() return end
    self:skip()
end

return Reveal
