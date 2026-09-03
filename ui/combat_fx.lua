-- Combat animation controller. The combat model (models/combat.lua) resolves an action instantly
-- and headlessly; it only records small plain-data cues (Combat.pushFx -> combat.fx). This view-side
-- controller turns a drained cue list into the reactions that make an exchange legible: a damage
-- number floats up, the struck unit shakes + flashes and its HP bar drains smoothly, the attacker
-- lunges, and a felled unit fades to black. It also carries the smooth tile-to-tile walk slide and
-- exposes a jiggle/fade the turn-strip cards read (ui/combat_panel.lua).
--
-- One instance per battle (states/battle.lua owns battle.fx and shares it into the board and panel):
--   fx:ingest(Combat.drainFx(combat), actor)   -- after an action resolves
--   fx:update(dt)                              -- every frame
--   local ox, oy, flash, fade = fx:spriteState(unit, tileSize)  -- board sprite draw
--   fx:drawFloaters(map)                       -- damage numbers, after the board
--
-- Everything here is created lazily inside :new()/on first use, never at require-time, so the model's
-- headless tests (which never touch the UI layer) stay free of love.graphics.

local Colors = require("ui.colors")
local ScreenFx = require("ui.screen_fx")
local BurstFx = require("ui.burst_fx")
local Sound = require("models.sound")
local Motif = require("ui.motif")
local Theme = require("ui.theme")

local CombatFx = {}
CombatFx.__index = CombatFx

-- Pacing / feel (readable-moderate). All in seconds unless noted; tuned so a single hit reads in
-- well under a second while staying clearly parseable.
local FLOAT_LIFE  = 0.85  -- how long a damage/heal number lingers as it drifts up
local FLOAT_RISE  = 42     -- px a floater climbs over its life
local SHAKE_TIME  = 0.26
local SHAKE_MAG   = 5       -- px, at the start of the shake (decays to 0)
local FLASH_TIME  = 0.22
local LUNGE_TIME  = 0.26    -- longer than the old 0.20: an anticipation and a follow-through both have
                            -- to fit inside it now (lungeCurve), and neither reads in three frames
local LUNGE_DIST  = 0.30    -- fraction of a tile the attacker leans toward its target
local CAST_TIME   = 0.30    -- an activation's lean-and-release beat on the CASTER (any ability)
local CAST_LEAN   = 0.26    -- fraction of a tile the caster thrusts toward its target as it casts
local CAST_BOB    = 0.16    -- fraction of a tile a self/tile cast (no aim direction) hops upward
local CAST_GLOW   = 0.85    -- peak additive glow on the caster mid-cast
local DEATH_TIME  = 0.55    -- fade-to-black duration for a felled unit
local BEAT_GAP    = 0.38    -- pause between an exchange's beats: a counter lands this long after the
                            -- blow it answers, so the two read as cause and reply rather than one hit.
                            -- Comfortably past SHAKE_TIME/FLASH_TIME, so the first hit's reaction has
                            -- finished before the answer begins.
local HP_SPEED    = 9        -- exponential drain rate of the shown HP toward the real value
local CARD_SHAKE_MAG = 5     -- px the struck unit's turn-strip card rumbles (synced to the sprite shake)
local HEAVY_HIT   = 12       -- damage at or above which a blow reads as heavy: an extra screen shake below,
                             -- and the punchier "battle.crit" cue instead of the ordinary "battle.hit". This
                             -- game rolls no critical hits, so a heavy blow IS the crit the cue names.
local CHARGE_STEP = 0.12     -- seconds per tile a forced rush (Charge) slides -- brisker than a walk step
local SHOVE_HOLD  = 0.22     -- a shove (knockback) stands its ground this long before travelling, so the
                             -- blow's damage number reads over the tile the target was struck ON. Matched
                             -- to FLASH_TIME: the hit finishes flashing, then the body goes.

-- ---------------------------------------------------------------------------
-- The programmatic animation set
-- ---------------------------------------------------------------------------
--
-- The board's end-state art was once specced as a Spine rig per combatant, whose commission brief
-- names six clips: idle, move, attack, hit, cast, death (docs/commission-board-sprites.md). All six
-- are authored HERE instead, as transform curves over a flat token -- which is what a unit displayed
-- at ~56px on a 64px tile can actually show. Skeletal deformation at that size is sub-pixel; what
-- reads is where the body is, how far it is leaning, and whether it is squashed or stretched.
--
-- So spriteState carries a full 2D transform -- offset, ROTATION and NON-UNIFORM SCALE -- and every
-- clip below is a curve on those three. Two rules hold the set together:
--
--   * The pivot is the FEET, not the centre (ui/battle_map.lua drawUnits draws bottom-anchored).
--     A body that topples or squashes around its middle reads as a spinning coin; around its feet it
--     reads as a body.
--   * Squash conserves volume -- a scale down on one axis is paid for by a scale up on the other.
--     Skip that and a squashed body just looks like a smaller body.
--
-- Every magnitude here is a fraction of a TILE (or radians), never a pixel count, so the whole set
-- survives the board zooming.

-- IDLE -- the loop everything else is layered over.
local IDLE_PERIOD = 1.9     -- seconds per breath
local IDLE_RATE   = 2 * math.pi / IDLE_PERIOD
-- These three were first authored at roughly half these values and were invisible on the board: at a
-- 64px tile, 0.016 of a tile is one pixel, and a one-pixel breath is not a breath. Anything meant to
-- read at this size has to be measured against the tile, then looked at.
local IDLE_RISE   = 0.030   -- fraction of a tile the body floats at the top of the breath
local IDLE_SWELL  = 0.030   -- how far it swells with it
local IDLE_TILT   = 0.014   -- radians of slow sway, at half the breath rate

-- MOVE -- what makes the tile-to-tile slide read as walking rather than gliding.
local MOVE_HOP    = 0.055   -- fraction of a tile the body rises at the top of each step
local MOVE_LEAN   = 0.085   -- radians it leans into the direction of travel
local MOVE_SQUASH = 0.055   -- compression at each footfall, stretch at each apex

-- ATTACK -- the four-phase curve below. The old motion was a symmetric sin(pi*t) out-and-back, which
-- is precisely why it read flat: a strike that leaves and returns at the same speed has no weight.
local LUNGE_WIND   = 0.22   -- of the clip: gathering BACKWARD off the target
local LUNGE_STRIKE = 0.34   -- ... to full extension by here
local LUNGE_HOLD   = 0.46   -- ... held there until here, then home
local LUNGE_BACK   = 0.26   -- fraction of LUNGE_DIST the wind-up pulls back
local LUNGE_TILT   = 0.17   -- radians the body leans into the swing
local LUNGE_STRETCH = 0.10  -- how far it stretches along the swing at extension

-- HIT -- a directional recoil, in place of the direction-blind jitter this used to be. The jitter is
-- kept for the one case that has no direction to recoil along (see spriteState).
local KNOCK_TIME   = 0.30
local KNOCK_DIST   = 0.17   -- fraction of a tile a full-weight blow throws the body
local KNOCK_SQUASH = 0.12
local KNOCK_TILT   = 0.15   -- radians it is rocked back off the line the blow came in on
local KNOCK_DECAY  = 4.5    -- how fast the recoil settles
local KNOCK_RING   = 8.0    -- and how many times it crosses zero on the way

-- CAST -- the gather before the release, layered under the existing lean/hop and glow.
local CAST_CROUCH = 0.34    -- of the clip spent compressing before the ability leaves
local CAST_SQUASH = 0.075

-- DEATH -- the collapse. Deliberately modest while the board still wears COMPOSED TOKENS
-- (tools/char_compose.lua): a token is an emblem on a baked plate, not a body, and a plate toppling
-- ninety degrees reads as the tile falling over. Painted art can afford a full fall; raise DEATH_TILT
-- toward math.pi/2 when it lands.
local DEATH_TILT   = 0.26   -- radians
local DEATH_SINK   = 0.09   -- fraction of a tile the body settles as it gives way
local DEATH_SQUASH = 0.10

local function easeOut(t) return 1 - (1 - t) * (1 - t) end

-- Smoothstep: eased at BOTH ends, for a motion that gathers and settles rather than one that snaps.
local function smooth(t) return t * t * (3 - 2 * t) end

-- The attack's displacement over the clip: progress 0..1 -> a multiple of LUNGE_DIST, which goes
-- NEGATIVE during the wind-up (the body pulls back off its target before it commits). Four phases,
-- in the proportions a strike actually has:
--
--   gather   ease back off the target        smooth, so the pull reads as loading rather than a twitch
--   strike   back foot to full extension     fast and decelerating into contact
--   hold     one beat at extension           the frame the blow reads on
--   recover  drift home                      the longest phase: follow-through is where weight lives
--
-- Contact lands at LUNGE_STRIKE (~0.06s in) while the victim's own reaction fires on the cue, so the
-- two are a few frames out of step. Close enough to read as cause and effect; syncing them exactly
-- would mean deferring the whole hit payload -- number, sound and screen shake -- onto the contact
-- frame, which is a bigger change than the gap is worth.
local function lungeCurve(p)
    if p < LUNGE_WIND then
        return -LUNGE_BACK * smooth(p / LUNGE_WIND)
    elseif p < LUNGE_STRIKE then
        local q = (p - LUNGE_WIND) / (LUNGE_STRIKE - LUNGE_WIND)
        return -LUNGE_BACK + (1 + LUNGE_BACK) * easeOut(q)
    elseif p < LUNGE_HOLD then
        return 1
    end
    return 1 - smooth((p - LUNGE_HOLD) / (1 - LUNGE_HOLD))
end

function CombatFx.new()
    local self = setmetatable({}, CombatFx)
    self.units = {}    -- unit -> { lungeT, lungeDx, lungeDy, shakeT, flashT, knockT, knockDx, knockDy,
                       --           knockMag, slideT, slideDur, slideFromX, slideFromY, dying, dead }
    -- Free-running seconds since the battle opened, which is what the IDLE loop is a function of --
    -- the one animation here with no cue behind it. Accumulated from dt rather than read off a clock,
    -- so a headless run that feeds fixed steps gets identical output every time.
    self.clock = 0
    self.phases = {}   -- unit -> its idle phase offset in radians (see :idlePhase)
    self.phaseN = 0
    -- Debug only (:demo / :setTimeScale, and the Animations page in ui/panels/debug_menu.lua). Both
    -- are inert at their defaults, so nothing here costs a normal battle anything.
    self.timeScale = 1
    self.demoQueue = {}
    self.loops = {}    -- clips repeating forever, for the Animation Gallery (:loopClip)
    self.floaters = {} -- list of { unit, text, color, age, life, jx, big }
    self.pending = {}  -- beats waiting their turn: { t = seconds left, events = cue list }
    self.hp = {}       -- unit -> shown HP value, eased toward hp.current
    self.held = {}     -- unit -> how many pending beats still owe it a hit; its HP bar waits on them
    self.heldStatus = {} -- status instance -> how many pending beats still owe it its landing; its
                         -- badge waits on them (a thrown Root, held through the bolt's flight)
    -- The point-effect controller (ui/burst_fx.lua), shared in by states/battle.lua once the board it
    -- draws on exists. Optional: the headless model tests build a CombatFx with none, and every call
    -- below guards on it, so an exchange resolves identically with or without a board to paint on.
    self.bursts = nil
    self.font = Theme.body(18)
    self.bigFont = Theme.body(24)
    return self
end

-- Per-unit reaction record, created on demand.
function CombatFx:reaction(unit)
    local r = self.units[unit]
    if not r then r = {}; self.units[unit] = r end
    return r
end

-- A stable phase offset for `unit`'s idle breath, in radians. Kept in a table of its own rather than
-- on the reaction record, because idle is the one animation a unit that has never acted still plays --
-- and :reaction() creating a record for every body on the board would quietly change what self.units
-- means to everything that walks it (:busy, :update).
--
-- Spaced by the golden angle, which is the point of the whole exercise: an idle whose phase is shared
-- makes a line of six guards breathe in lockstep, and lockstep is the tell that gives a procedural
-- animation away instantly. Successive multiples of the golden ratio never bunch up, so neighbours on
-- the board land far apart on the cycle. Assigned by a counter, never a clock or a random draw, so the
-- board animates identically on a replay.
function CombatFx:idlePhase(unit)
    local ph = self.phases[unit]
    if not ph then
        self.phaseN = self.phaseN + 1
        ph = ((self.phaseN * 0.6180339887498949) % 1) * 2 * math.pi
        self.phases[unit] = ph
    end
    return ph
end

-- ---------------------------------------------------------------------------
-- Turning model cues into animations
-- ---------------------------------------------------------------------------

-- Drain-and-feed: `events` is a Combat.drainFx list (or nil); `actor` is the unit that acted, which
-- leans toward the first thing it hurt. Pass actor = nil for incidental damage with no attacker to
-- lean (a trap/hazard/overwatch hit taken mid-walk), which then just floats and shakes the victim.
--
-- The model resolves a whole exchange in one pass, so a batch can hold both a blow and the counter it
-- provoked. Playing those together reads as one indecipherable flash, so each cue's `beat` (stamped by
-- Combat.pushFx: 0 for the action, 1 for what answered it, 2 for the answer to that) is split out and
-- played in order, BEAT_GAP apart. Beats are compared, never counted: a batch that is entirely
-- reactions (a trap answering a walk) starts at once, since its earliest beat is its own beat 0.
function CombatFx:ingest(events, actor)
    if not events then return end
    local order, byBeat = {}, {}
    for _, e in ipairs(events) do
        local b = e.beat or 0
        if not byBeat[b] then byBeat[b] = {}; order[#order + 1] = b end
        local list = byBeat[b]
        list[#list + 1] = e
    end
    table.sort(order)
    for i, b in ipairs(order) do
        if i == 1 then
            self:playBeat(byBeat[b], actor)
        else
            -- Deferred beats carry no actor: only the unit that opened the exchange leans off the
            -- batch, while a counter-striker leans off its own cue's `attacker` inside playBeat.
            self.pending[#self.pending + 1] = { t = (i - 1) * BEAT_GAP, events = byBeat[b] }
            self:hold(byBeat[b], 1)
            self:pinSlides(byBeat[b])
        end
    end
end

-- Claim (delta 1) or release (delta -1) the units a deferred beat has yet to touch. The model resolved
-- the whole exchange before we saw any of it, so a counter's damage is ALREADY off the attacker's
-- health -- and a unit the counter felled is ALREADY alive = false -- while its beat still waits to
-- play. Without this the bar would drain and the corpse drop a beat early, giving the answer away
-- before it lands. Counted, not a flag, so overlapping beats on one unit release it only once the last
-- of them has played.
function CombatFx:hold(events, delta)
    for _, e in ipairs(events) do
        if e.type == "damage" or e.type == "heal" or e.type == "death" then
            local n = (self.held[e.unit] or 0) + delta
            self.held[e.unit] = n > 0 and n or nil
        elseif e.type == "status" and e.status then
            -- The badge's twin of the health hold above: the status is on the unit in the model the
            -- instant the blow resolves, but a thrown affliction (Bolas' Root) must not paint its badge
            -- until the bolt is seen to land. Counted per status instance so the badge surfaces the
            -- moment this beat plays (:update's hold(-1)), exactly with the impact -- see statusPending.
            local n = (self.heldStatus[e.status] or 0) + delta
            self.heldStatus[e.status] = n > 0 and n or nil
        end
    end
end

-- The positional twin of :hold, for the shoves a withheld cue list is sitting on. A knockback is
-- resolved in the model the instant the exchange is, so the target's unit.x/unit.y ALREADY read as the
-- far tile while the cue that shoves it there waits its turn -- for BEAT_GAP if it is a counter, or for
-- a whole approach walk if the blow was carried (states/battle.lua holdLanding). Left alone the board
-- draws the body standing on its destination for that entire wait, and then the cue plays and yanks it
-- back to its origin to glide across a second time: it teleports, THEN animates.
--
-- So the sprite is pinned to its origin here, the moment we learn a shove is coming, with an unbounded
-- hold. When the cue finally plays, playBeat's ordinary forcedSlide re-arms it from that same origin --
-- seamless, since that is where the sprite already stands -- and it travels exactly once.
--
-- Deliberately ungated (unlike a live forced slide): a pin is a unit standing still, and must never be
-- a reason the turn hand-off waits. Only the real slide that follows it gates.
--
-- `walking` is the unit whose approach walk is replaying right now (states/battle.lua battle.walk), if
-- any -- and it is NEVER pinned. A pin assumes its subject is standing still on the shove's origin, but
-- a hit-and-run blow (wolf Fangs) shoves the STRIKER, and the striker is the same body still walking in.
-- Pinning it would clobber the walk slide walkStep is driving and stamp the sprite onto the shove's
-- origin -- so the wolf flashes at its destination instead of walking there. The walk plays that unit's
-- motion, and playBeat's forcedSlide arms its give-ground once the feet stop, so it needs no pin.
function CombatFx:pinSlides(events, walking)
    for _, e in ipairs(events) do
        if e.type == "slide" and e.unit ~= walking then
            local dist = math.abs(e.fromX - e.unit.x) + math.abs(e.fromY - e.unit.y)
            if dist > 0 then
                self:setSlide(e.unit, e.fromX, e.fromY, dist * CHARGE_STEP, false, nil, nil, math.huge)
            end
        end
    end
end

-- Does a beat still waiting to play owe `unit` something? True between the model resolving a blow and
-- the view getting round to showing it. The board reads it to keep drawing a unit the model has
-- already killed (and to hold its corpse token back) until the counter that felled it actually plays.
function CombatFx:awaiting(unit)
    return self.held[unit] ~= nil
end

-- Is `status` a fresh affliction whose landing cue a pending beat still owes? True from the instant the
-- model applies it until the beat that lands it plays -- the window a thrown Root spends riding the bolt
-- to its target. The badge draw reads it to keep the badge off the body until the hit is seen to land,
-- so an affliction never surfaces ahead of the blow that carries it (ui/battle_map.lua statusBadgeRects).
function CombatFx:statusPending(status)
    return self.heldStatus[status] ~= nil
end

-- The side and command a unit should be DRAWN with right now, which is not always the pair it holds.
--
-- Charm is the one status that changes a body's ALLEGIANCE (data/status/status_charm.lua), and the
-- model flips it the instant the cast resolves -- which is a whole approach walk and an impact beat
-- before the blow is seen to land. Left alone the board reads the turn out of order and gives the
-- ending away: a party member goes red, moves to the enemy's colours and starts wearing an enemy
-- intent icon while the thing that took them is still three tiles off walking in, and only then does
-- the touch land. The badge was already held back for exactly this reason (:statusPending, above);
-- this is the rest of the same sentence, and the two now surface together.
--
-- Keyed off the very hold the badge uses, so there is one clock and no second latch to fall out of
-- sync: while the charm's landing cue is still owed the unit draws as the side it was taken FROM
-- (`_charmSide`/`_charmControl`, the pair the status stashed to revert to). Drawing only -- the model,
-- the AI and every rule still read the true side, because the body really has changed hands.
function CombatFx:shownAllegiance(unit)
    if type(unit) ~= "table" then return unit, nil end
    if unit._charmSide then
        for _, st in ipairs(unit.statuses or {}) do
            if st.id == "status_charm" and self:statusPending(st) then
                return unit._charmSide, unit._charmControl
            end
        end
    end
    return unit.side, unit.control
end

-- ...and that pair as a colour, so every surface that paints a body asks one question and gets one
-- answer (ui/battle_map.lua's token frame and HP bar, ui/combat_panel.lua's cards).
function CombatFx:unitColor(unit)
    return Colors.allegiance(self:shownAllegiance(unit))
end

-- The tile gap between two units, king's-move: an attacker two or more tiles from the body it struck
-- is shooting, not swinging, and its blow should cross the board before it lands.
local function tileGap(a, b)
    if not (a and b) then return 0 end
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

-- Where each unit in this beat was standing when the blow LANDED on it.
--
-- A shove folded into a strike (the mace, Shield Shove, a thrown body) is resolved by the model in the
-- same atomic pass as the damage, so by the time the view sees the cue the target's unit.x/unit.y
-- ALREADY reads as the tile it ends up on -- while the sprite is still standing where it was hit,
-- pinned there by :pinSlides and held by SHOVE_HOLD. Every picture of the blow has to be drawn on the
-- tile the body was ON, not the one it is about to occupy: the impact burst, the lean of whoever swung,
-- and above all the projectile, which otherwise sails past the target to the far end of the shove
-- before the target has so much as flinched.
--
-- The shove cue carries that origin (`hold` marks a slide the blow itself threw, see
-- Combat.shoveDone), so this reads it back out. Returned as bare {x, y} tables, which stand in for a
-- unit anywhere a cell is all that is wanted.
local function struckCells(events)
    local at = {}
    for _, e in ipairs(events) do
        if e.type == "slide" and e.hold then at[e.unit] = { x = e.fromX, y = e.fromY } end
    end
    return at
end

-- The direction a blow came from, attacker -> victim, in radians (board space, +y down). A slash
-- sweeps across it and a stab drives along it; 0 for a wound with no striker (a toll, a poison tick),
-- which the radially-symmetric default burst does not read anyway.
-- Turned into a SCREEN angle before it leaves (see CombatFx:rotate): the two cells are grid cells, and
-- on a rotated board a sweep that kept its grid heading would cut across the blow that caused it.
local function strikeAngle(fx, attacker, victim)
    if not (attacker and victim) then return 0 end
    local dx, dy = victim.x - attacker.x, victim.y - attacker.y
    if dx == 0 and dy == 0 then return 0 end
    local rdx, rdy = fx:rotate(dx, dy)
    return math.atan2(rdy, rdx)
end

-- A blow that THROWS something becomes a projectile: the shooter leans and its shot fires NOW, but the
-- wound -- the number, the shake, the impact burst, any shove or death that rode with it -- waits until
-- the bolt actually arrives. Detected here, on the first play of a beat; the reactions are split off
-- into a delayed replay of the same beat, which re-enters playBeat flagged `_delayed` and takes the
-- ordinary melee path below.
--
-- Which blows those are is the ITEM's business, read off its tags by BurstFx.throwsProjectile rather
-- than guessed from the tiles between the two bodies: a mace is a mace at any reach, and a wand is a
-- wand at point-blank. Distance only breaks the tie for the blows that state no routing at all. The gap
-- it measures runs to the tile the target was STRUCK on -- a shove that has already resolved in the
-- model must not be mistaken for the shooting distance, which is the exact way a mace used to fire.
--
-- This reuses the exact machinery a counter already uses (self.pending / :hold / :pinSlides / :busy),
-- so nothing new gates the turn hand-off: a bolt in the air is just one more beat not yet played.
-- Returns true if it deferred (the caller must stop), false to fall through to an immediate melee beat.
function CombatFx:deferRanged(events, actor)
    if events._delayed or not self.bursts then return false end
    local struck = struckCells(events)
    local far = {}
    for _, e in ipairs(events) do
        -- A blow that wounded its own striker (recoil, a backfire) crossed nothing, whatever it was
        -- thrown with, so it never flies -- the routing tags below would otherwise loose a bolt from a
        -- body to itself.
        if e.type == "damage" and e.attacker and e.attacker ~= e.unit then
            local cell = struck[e.unit] or e.unit
            if BurstFx.throwsProjectile(e.tags, tileGap(e.attacker, cell)) then
                far[#far + 1] = e
            end
        end
    end
    if #far == 0 then return false end

    -- Launch a bolt per far blow -- aimed at the tile the body is standing on, NOT the one its own
    -- knockback is about to put it on -- and take the longest flight as the beat's delay.
    local dur = 0
    for _, e in ipairs(far) do
        local cell = struck[e.unit] or e.unit
        dur = math.max(dur, self.bursts:flight(e.attacker.x, e.attacker.y, cell.x, cell.y, e.tags,
            { lethal = e.lethal }))
    end

    -- The immediate half fires now: any cast cue (the shooting motion + glow), and the shooter's lean.
    -- The rest is held back to replay when the bolt lands.
    local now, later = {}, {}
    for _, e in ipairs(events) do
        if e.type == "cast" then now[#now + 1] = e else later[#later + 1] = e end
    end
    later._delayed = true
    if #now > 0 then self:playBeat(now, actor) end
    for _, e in ipairs(far) do self:lunge(e.attacker, struck[e.unit] or e.unit) end

    self.pending[#self.pending + 1] = { t = dur, events = later }
    self:hold(later, 1)
    self:pinSlides(later)
    return true
end

-- The impact sound for a surviving blow, chosen by its DAMAGE TYPE. `battle.hit_<motif>` when that
-- element/strike carries its own cue (fire, ice, slash, ...); otherwise the generic `battle.hit`, or the
-- heavier `battle.crit` for a big untyped blow. Motif.of reads the same tag order the burst does, so the
-- sound a blow makes and the burst it throws always name the same element. A heavy TYPED hit rings its
-- own cue pitched down a touch, so the element still reads as "more" without a separate crit sound.
-- `critical` now means what the cue's name always claimed. `battle.crit` shipped long before the dice
-- did, and fired on any blow of 12 or more -- a stand-in for "that was a big one" while there was no
-- such thing as a critical hit to ring for. There is now, so a real crit takes the cue outright, and
-- the heavy-blow rule stays underneath it for an ordinary blow that simply hit hard.
local function playHit(amount, tags, critical)
    local heavy = (amount or 0) >= HEAVY_HIT
    local motif = Motif.of(tags)
    local id = motif and ("battle.hit_" .. motif)
    -- A crit rings the crit cue even when the blow carries an element: the dice outrank the damage
    -- type here, because "that was a critical" is the thing the player most needs to hear, and a fire
    -- crit that sounded exactly like a fire hit would only be legible from the number.
    if critical then
        Sound.play("battle.crit")
    elseif id and Sound.cues[id] then
        Sound.play(id, heavy and { pitch = 0.9 } or nil)
    else
        Sound.play(heavy and "battle.crit" or "battle.hit")
    end
end

-- Play one beat's worth of cues -- the reactions for a single blow and everything simultaneous with it.
function CombatFx:playBeat(events, actor)
    if self:deferRanged(events, actor) then return end
    local delayed = events._delayed
    -- Where the bodies in this beat are STANDING as it plays, which is not where the model has already
    -- put the ones this blow shoves (see struckCells). Everything drawn at the point of impact is
    -- placed against these, so the burst marks the tile the sprite is on and the lean points at it.
    local struck = struckCells(events)
    local firstTarget, firstTargetCell
    local actorCast = false -- did the acting unit already play a cast beat this batch?
    for _, e in ipairs(events) do
        if e.type == "cast" then
            self:cast(e.unit, e.tx, e.ty, e.support, e.harmless)
            if e.unit == actor then actorCast = true end
            -- The activation itself makes a sound: the swing under an attack's impact, or an ability
            -- firing. Only offensive casts ring it -- a support cast (heal/buff) is announced by its own
            -- heal/buff cue below, so it would only double up here. A HARMLESS cast (a foe assayed, not
            -- struck) rings the neutral shimmer instead: it is an activation, so it must be heard, but
            -- the swing is the one thing it is not.
            if e.harmless then Sound.play("battle.status")
            elseif not e.support then Sound.play("battle.cast") end
            -- A friendly cast (a heal, a blessing) rises as motes off the caster; an offensive cast
            -- leaves its mark through the damage bursts its blows spawn, so it gets none here. A
            -- harmless one spawns no blow at all, so it marks the BODY IT READ -- a sigil on the foe's
            -- own tile -- or nothing on the board would say where the working landed.
            if self.bursts and e.harmless then
                self.bursts:support(e.tx or e.unit.x, e.ty or e.unit.y, "sigil")
            elseif self.bursts and e.support then
                self.bursts:support(e.unit.x, e.unit.y, "motes")
            end
        elseif e.type == "damage" then
            local cell = struck[e.unit] or e.unit
            -- `cell`, not e.unit, for the same reason the burst below marks it: a blow that also
            -- shoves has already moved the model, and the recoil has to be measured from the tile the
            -- body is still being DRAWN on.
            self:hit(e.unit, e.amount, e.lethal, e.attacker, cell, e.critical)
            -- A killing blow's audio is the "death" cue below, not a hit on top of it; a surviving blow
            -- rings its damage-type impact (see playHit).
            if not e.lethal then
                playHit(e.amount, e.tags, e.critical)
            end
            -- Only a blow the ACTOR itself struck feeds the actor-fallback lean below. Incidental
            -- damage sharing this beat -- a Burn/Poison tick, a trap, a hazard, all of which carry no
            -- attacker (models/combat.lua dealFlatDamage) -- is nobody's swing, so it must never make
            -- the acting unit lunge at a body it never touched.
            if actor and e.attacker == actor and not firstTarget then
                firstTarget, firstTargetCell = e.unit, cell
            end
            if self.bursts then
                self.bursts:strike(cell.x, cell.y, e.tags,
                    { angle = strikeAngle(self, e.attacker, cell), lethal = e.lethal, vulnerable = e.vulnerable })
            end
            -- A blow struck by someone other than the acting unit -- a counter, a riposte, a thorns
            -- answer -- leans off its own cue, since the actor fallback below can't speak for it. On a
            -- delayed replay the shooter already leaned as it fired, so it must not lean again on impact.
            if not delayed and e.attacker and e.attacker ~= actor and e.attacker ~= e.unit then
                self:lunge(e.attacker, cell)
            end
        elseif e.type == "heal" then
            self:floatText(e.unit, "+" .. tostring(e.amount), { 0.55, 0.95, 0.60 })
            if self.bursts then self.bursts:support(e.unit.x, e.unit.y, "motes") end
            Sound.play("battle.heal")
        elseif e.type == "status" then
            -- A no-visual cue carried only for its sound: a status LANDING on a unit (models/status.lua
            -- pushes it on a fresh application). The badge/field the status paints is drawn elsewhere.
            -- Buff and debuff ring differently so the player can tell "I was helped" from "I was hit";
            -- a status of unknown valence falls back to the neutral status cue.
            local def = e.status and e.status.def
            if def and def.debuff then
                Sound.play("battle.debuff")
            elseif def then
                Sound.play("battle.buff")
            else
                Sound.play("battle.status")
            end
        elseif e.type == "burst" then
            -- A standalone detonation on a tile (models/combat.lua Combat.spawnBurst): a bomb going off,
            -- drawn from the tile it went off ON rather than off a body it hit -- so it reads even when
            -- the blast caught nobody, and even though the bomber that raised it (fx.expendSelf) is
            -- already gone. The wound the blast deals rides on its own damage cues; this is the boom over
            -- them: a big fire bloom, one down-pitched hit_fire so a whiff still sounds, and a short shake.
            if self.bursts then
                self.bursts:strike(e.x, e.y, e.tags, { radius = e.radius or 1.6, intensity = 1.3, lethal = e.lethal })
            end
            Sound.play("battle.hit_fire", { pitch = 0.85 })
            ScreenFx.shake(4, 0.24)
        elseif e.type == "channel" then
            -- A powerful spell begins winding up (models/combat.lua on commit). Sound-only: the board's
            -- own telegraph draws the footprint, so this just voices the charge.
            Sound.play("battle.channel")
        elseif e.type == "miss" then
            -- A blow that landed nothing -- the hit roll failed, or it was dodged, smoked or
            -- substituted (models/combat.lua).
            --
            -- IT FLOATS A WORD NOW, and that is not decoration. The sound used to be the only tell,
            -- which was tolerable while a miss meant one of three rare reflexes had fired; since
            -- accuracy it is the single most common thing that happens to an attack, and a turn whose
            -- only feedback is a noise reads as the game having ignored the click. The float lands
            -- where the damage number would have, so the eye is already looking at it.
            --
            -- Cool steel rather than a damage colour: nothing happened to this body, and the reds are
            -- reserved for things that did.
            self:floatText(e.unit, "MISS", { 0.62, 0.70, 0.78 })
            Sound.play("battle.miss")
        elseif e.type == "slide" then
            -- If this cue was pinned while it waited (see :pinSlides) the sprite is already sitting on
            -- its origin tile, so arming the real slide here picks up exactly where the pin left off
            -- rather than jumping back to it.
            self:forcedSlide(e.unit, e.fromX, e.fromY, e.hold and SHOVE_HOLD or nil)
        elseif e.type == "death" then
            self:reaction(e.unit).dying = DEATH_TIME
            Sound.play("battle.death")
        elseif e.type == "exit" then
            -- A body that walked off rather than fell (Combat.withdraw -- a rotation). The same fade,
            -- so the board token and the timeline card both animate out instead of blinking, and
            -- deliberately silent: the rotation already made its own sound, and the death knell over
            -- a unit that is standing perfectly well on the bench would be a lie.
            self:reaction(e.unit).dying = DEATH_TIME
        end
    end
    -- The caster's own motion comes from its "cast" cue now. Fall back to the old damage-derived lunge
    -- only when the actor drew blood WITHOUT casting -- a counterattack or a reaction trait, which hits
    -- through no ability of its own -- so such a blow still leans toward the unit it hurt.
    if actor and not actorCast and firstTarget and actor ~= firstTarget then
        self:lunge(actor, firstTargetCell)
    end
end

-- Play a cast/activation beat on `unit` as it looses an ability at cell (tx, ty): a lean-and-release
-- toward the aim -- a vertical hop for a self/tile cast with no direction -- plus a colored glow, green
-- for a friendly cast (heal/buff), warm gold for an offensive one. The model pushes a "cast" cue for
-- EVERY ability activation, so a cure, a summon or a self-buff reads on the board, not just a strike.
--
-- A HARMLESS cast (Combat.isHarmlessAbility -- a foe read rather than hit) glows the same steel-cyan
-- its reach band wears, and does NOT lean: the lean is the picture of a body throwing its weight at
-- another one, which is exactly the reading the flag exists to withdraw. It bobs in place instead,
-- like a cast aimed at nobody.
function CombatFx:cast(unit, tx, ty, support, harmless)
    local r = self:reaction(unit)
    local dx, dy = (tx or unit.x) - unit.x, (ty or unit.y) - unit.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1e-4 and not harmless then r.castDx, r.castDy = dx / len, dy / len
    else r.castDx, r.castDy = nil, nil end -- aimed at its own tile (self/tile cast): bob in place
    r.castT = CAST_TIME
    if harmless then r.castColor = { 0.55, 0.85, 0.92 }
    else r.castColor = support and { 0.55, 0.95, 0.70 } or { 0.98, 0.82, 0.45 } end
end

-- A blow landing on `unit`: shake + flash the sprite, float the number, jiggle its card. Damage
-- floats red (a brighter red on a killing blow); heals float green (see ingest).
-- `attacker` and `cell` are what turn the reaction from a jitter into a RECOIL: the body is thrown
-- along the line the blow came in on, rocked back off it and compressed by it, all scaled by how hard
-- the blow was. `cell` is where the struck body is STANDING as this plays, which is not unit.x/unit.y
-- when the same blow also shoves it (playBeat's struckCells) -- measuring the direction against the
-- tile it has already been moved to would recoil it the wrong way. Both are optional: damage with no
-- attacker at all (a Burn tick, a hazard, a trap) has no line to recoil along and keeps the
-- direction-blind shake instead.
function CombatFx:hit(unit, amount, lethal, attacker, cell, critical)
    local r = self:reaction(unit)
    r.shakeT = SHAKE_TIME
    r.flashT = FLASH_TIME
    if attacker then self:knock(unit, attacker, amount, cell) end
    -- A CRITICAL reads as one before the player has finished counting the number. It floats in the
    -- warm gold this UI reserves for "live" (Theme's accentAmber family) rather than the damage reds,
    -- and at the big size a killing blow uses -- the two things a crit has in common with a kill are
    -- that it is rare and that it decides something, so they are allowed to share an emphasis. The
    -- colour is what keeps them apart: red is what happened to the body, gold is what the dice did.
    local color = { 0.95, 0.28, 0.26 }
    if critical then
        color = { 1.0, 0.78, 0.30 }
    elseif lethal then
        color = { 1.0, 0.42, 0.38 }
    end
    self:floatText(unit, tostring(amount), color, lethal or critical)
    -- The card's rumble + flash read the same shakeT/flashT below, so they land in sync with the sprite.
    -- A killing blow reaches past the struck body to the whole frame: a brief hit-stop, a punch and a
    -- shake, so a death lands with weight. These no-op under the reduced-effects setting (ui/screen_fx).
    -- A heavy but non-lethal blow gets a proportional shake alone -- a scratch does not move the camera.
    if lethal then
        ScreenFx.freeze(0.07)
        ScreenFx.punch(0.7)
        ScreenFx.shake(6, 0.32)
    elseif (amount or 0) >= HEAVY_HIT then
        ScreenFx.shake(math.min(4, amount * 0.2), 0.22)
    end
end

function CombatFx:floatText(unit, text, color, big)
    self.floaters[#self.floaters + 1] = {
        unit = unit, text = text, color = color, age = 0, life = FLOAT_LIFE,
        jx = math.random(-7, 7), big = big,
    }
end

-- Throw `unit` AWAY from `attacker` -- the hit reaction's direction, normalised so a body shot from
-- across the board recoils as truly as one that was stabbed. Magnitude rides the damage: a scratch
-- barely rocks the body and a heavy blow throws it the full KNOCK_DIST, so the same clip says how bad
-- it was. HEAVY_HIT is the ceiling because it is already this file's word for "that one hurt" -- the
-- screen shake and the crit cue both read it.
function CombatFx:knock(unit, attacker, amount, cell)
    cell = cell or unit
    local dx, dy = cell.x - attacker.x, cell.y - attacker.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-4 then return end -- struck by something standing on its own tile: nothing to recoil off
    local r = self:reaction(unit)
    r.knockDx, r.knockDy = dx / len, dy / len
    r.knockMag = math.max(0.35, math.min(1, (amount or 0) / HEAVY_HIT))
    r.knockT = KNOCK_TIME
end

-- Aim `unit`'s lunge toward `target` (normalised so a ranged attacker leans the right way too).
function CombatFx:lunge(unit, target)
    local dx, dy = target.x - unit.x, target.y - unit.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-4 then return end
    local r = self:reaction(unit)
    r.lungeDx, r.lungeDy = dx / len, dy / len
    r.lungeT = LUNGE_TIME
end

-- Start a smooth slide of `unit` from the cell it just left toward the cell it now occupies, played
-- out over `dur` (states/battle.lua drives one per walked tile). Purely visual: the model position
-- is already the destination cell. A walk drives one per tile and paces itself, so its slide is not
-- gated; a `gate` slide (a forced rush covering several tiles at once) instead holds the turn hand-off
-- until it finishes, so the rush reads before the turn passes.
-- `toX`/`toY` name the tile the slide ARRIVES on, and default to where the model already put the
-- unit -- which is the whole story for a single step or a forced rush. A replayed walk is the case
-- that needs them said out loud: the model finished the entire route before the first frame was
-- drawn, so the sprite is crossing from one middle-of-the-route tile to the next while unit.x/unit.y
-- already read as the far end. Without a stated destination every step would be measured against
-- that far end and the sprite would snap there on the first one.
-- `delay` holds the sprite still on its ORIGIN tile that long before the travel begins (see
-- SHOVE_HOLD). The unit is pinned by the same offset the slide starts from, so a held slide simply
-- looks like a unit that has not moved yet -- which is the point: the damage it was just dealt floats
-- over the tile it was standing on, and only then is it thrown.
function CombatFx:setSlide(unit, fromX, fromY, dur, gate, toX, toY, delay)
    local r = self:reaction(unit)
    r.slideFromX, r.slideFromY = fromX, fromY
    r.slideToX, r.slideToY = toX, toY
    r.slideT, r.slideDur = dur, dur
    r.slideGate = gate or nil
    r.slideHold = (delay and delay > 0) and delay or nil
end

-- A forced multi-tile slide (Charge, knockback): `unit` glides from (fromX, fromY) to where the model
-- already put it, over a duration scaled to the tiles crossed so a longer drive takes longer. Gated,
-- so the rush finishes before the turn hands off. `delay` (a shove) stalls the start; a charge, whose
-- damage lands at the END of the run, takes none and leaves at once.
function CombatFx:forcedSlide(unit, fromX, fromY, delay)
    local dist = math.abs(fromX - unit.x) + math.abs(fromY - unit.y)
    if dist == 0 then return end
    self:setSlide(unit, fromX, fromY, dist * CHARGE_STEP, true, nil, nil, delay)
end

-- ---------------------------------------------------------------------------
-- Per-frame advance
-- ---------------------------------------------------------------------------

function CombatFx:update(dt)
    -- Debug slow motion (:setTimeScale). Applied to the WHOLE controller rather than to the sprite
    -- curves alone, so a clip slowed down to be looked at keeps its beats, its bursts and its floaters
    -- in the same relation to each other -- half the point of watching it slowly is seeing whether a
    -- reaction still lands where the blow does.
    dt = dt * (self.timeScale or 1)
    self.clock = self.clock + dt -- drives the idle loop, which answers to no cue

    -- Debug demo steps coming due (:demo). Walked back-to-front so a removal cannot skip the next.
    for i = #self.demoQueue, 1, -1 do
        local d = self.demoQueue[i]
        d.t = d.t - dt
        if d.t <= 0 then table.remove(self.demoQueue, i); d.fn() end
    end
    -- Clips repeating forever (:loopClip) -- the Animation Gallery's whole engine.
    for _, L in ipairs(self.loops) do
        L.t = L.t - dt
        if L.t <= 0 then L.t = L.period; self:demo(L.unit, L.target, L.clip) end
    end
    -- A deferred beat comes due: play its cues now, exactly as if they had just been drained. Walked
    -- back-to-front so a removal can't skip the next entry; a beat that fires cannot enqueue another
    -- (ingest is the only writer), so the list always drains.
    for i = #self.pending, 1, -1 do
        local p = self.pending[i]
        p.t = p.t - dt
        if p.t <= 0 then
            table.remove(self.pending, i)
            self:hold(p.events, -1) -- its bars may drain now: the blow is landing this frame
            self:playBeat(p.events, nil)
        end
    end
    -- Floaters age out.
    for i = #self.floaters, 1, -1 do
        local f = self.floaters[i]
        f.age = f.age + dt
        if f.age >= f.life then table.remove(self.floaters, i) end
    end
    -- Per-unit reaction timers.
    for _, r in pairs(self.units) do
        if r.lungeT then r.lungeT = r.lungeT - dt; if r.lungeT <= 0 then r.lungeT = nil end end
        if r.castT then r.castT = r.castT - dt; if r.castT <= 0 then r.castT = nil end end
        if r.shakeT then r.shakeT = r.shakeT - dt; if r.shakeT <= 0 then r.shakeT = nil end end
        if r.flashT then r.flashT = r.flashT - dt; if r.flashT <= 0 then r.flashT = nil end end
        -- The recoil outlives the flash, so a body is still settling after it has stopped glowing.
        -- knockDx/knockDy are deliberately NOT cleared with it: the death collapse reads them to
        -- decide which way a felled body goes down (see spriteState).
        if r.knockT then r.knockT = r.knockT - dt; if r.knockT <= 0 then r.knockT = nil end end
        if r.slideHold then
            -- Held at the origin: burn the stall down first, and leave slideT untouched so the sprite
            -- keeps drawing on the tile it started from.
            r.slideHold = r.slideHold - dt
            if r.slideHold <= 0 then r.slideHold = nil end
        elseif r.slideT then
            r.slideT = r.slideT - dt
            if r.slideT <= 0 then
                r.slideT = nil; r.slideDur = nil; r.slideGate = nil
                r.slideToX, r.slideToY = nil, nil
            end
        end
        if r.dying then
            r.dying = r.dying - dt
            if r.dying <= 0 then r.dying = nil; r.dead = true end
        end
    end
    -- Shown HP eases toward the real current value (both directions -- drain and heal), except on a
    -- unit a pending beat still owes a hit -- its bar holds until that blow actually plays (see :hold).
    for unit, val in pairs(self.hp) do
        local hp = unit.char and unit.char.stats and unit.char.stats.health
        if hp and not self.held[unit] then
            local nv = val + (hp.current - val) * math.min(1, dt * HP_SPEED)
            if math.abs(nv - hp.current) < 0.5 then nv = hp.current end
            self.hp[unit] = nv
        end
    end
end

-- True while a reaction still needs to read: the gate states/battle.lua holds the turn hand-off on.
-- Floaters, card jiggle, HP drain and the walk slide are all deliberately excluded -- they may drift
-- into the next turn without stalling the pace.
function CombatFx:busy()
    -- A beat still waiting to play is the loudest reason to hold the hand-off: the exchange is not
    -- over until the counter it is holding has landed.
    if #self.pending > 0 then return true end
    for _, r in pairs(self.units) do
        -- A gated slide (a forced Charge rush) holds too, so the drive lands before the turn passes;
        -- a plain walk slide (slideGate nil) still drifts freely, paced by the walk loop itself.
        if r.lungeT or r.castT or r.shakeT or r.flashT or r.knockT or r.dying or (r.slideT and r.slideGate) then return true end
    end
    return false
end

-- True once every strip/board HP bar has finished draining to its real value -- the slowest hit
-- reaction to settle. The turn hand-off waits on this (on top of busy()) so a bar isn't still draining
-- while the turn-order cards restage. Kept out of busy() so it never stalls player INPUT, only the
-- automatic hand-off.
function CombatFx:hpSettled()
    for unit, val in pairs(self.hp) do
        local hp = unit.char and unit.char.stats and unit.char.stats.health
        if hp and math.abs(val - hp.current) >= 0.5 then return false end
    end
    return true
end

-- True once every damage/heal number has drifted up and faded -- the last of the "damage animation"
-- to clear. The turn hand-off waits on this too, so a number is never still floating on the board while
-- the turn-order cards restage. (Its lifetime, FLOAT_LIFE, therefore paces the beat between a hit
-- landing and the turn moving.)
function CombatFx:floatersDone()
    return #self.floaters == 0
end

-- ---------------------------------------------------------------------------
-- Read-outs for the draw layer
-- ---------------------------------------------------------------------------

-- Sprite draw modifiers for `unit` at tile size `size` -- the whole animation set (see "The
-- programmatic animation set" above) collapsed into one transform, plus the two colour channels:
--
--   offX, offY   pixel offset: walk slide, idle float, step hop, attack lunge, cast lean, hit recoil
--   flash        0..1 white/red hit flash
--   fade         0..1 death fade (0 = untouched, 1 = fully faded out)
--   rot          radians: idle sway, walk lean, swing lean, hit rock, death topple
--   sx, sy       non-uniform scale: breath, footfall squash, swing stretch, impact compression
--
-- The draw site must pivot rot/sx/sy at the sprite's BOTTOM edge, not its centre (ui/battle_map.lua
-- drawUnits) -- these curves are all authored as things a body does while its feet stay put.
-- Every unit gets an answer, including one with no reaction record: idle answers to no cue.
-- Pixel offset of `unit`'s in-flight slide from the tile the model has it on, or 0,0 when it is not
-- travelling. Split out from spriteState because the damage numbers need this ONE part of the sprite's
-- displacement and none of the rest: a floater rides along with a shoved body, but must not inherit
-- the hit shake or the attack lunge (a number that jitters is a number you can't read).
-- Turn a GRID delta into the screen delta that draws it. Identity here, and replaced by the board with
-- its own facing (ui/battle_map.lua's syncFx) whenever the picture is rotated -- a step to grid-east
-- has to slide toward whichever screen edge grid-east is currently pointing at. Everything in this file
-- that displaces a sprite along the board's axes goes through it; the flourishes that are about the
-- SCREEN rather than the board -- the hit shake, the little upward hop of a self-cast -- deliberately
-- do not, because "up" means up to the player whichever way the board is facing.
function CombatFx:rotate(dx, dy)
    return dx, dy
end

function CombatFx:slideOffset(unit, size)
    local r = self.units[unit]
    if not (r and r.slideT and r.slideDur) then return 0, 0 end
    -- Held at the origin (a shove waiting on its damage number): no progress yet, e pins to 0.
    local e = r.slideHold and 0 or easeOut(1 - r.slideT / r.slideDur)
    -- Where the step lands, which is usually just where the unit already is. The offset is the
    -- gap between the eased point along this step and the model's tile: interpolate from -> to,
    -- then measure that back against unit.x/unit.y (see setSlide). With to == unit.x this is
    -- exactly the old (from - unit.x) * (1 - e).
    local toX = r.slideToX or unit.x
    local toY = r.slideToY or unit.y
    return self:rotate(((r.slideFromX - toX) * (1 - e) + (toX - unit.x)) * size,
                       ((r.slideFromY - toY) * (1 - e) + (toY - unit.y)) * size)
end

function CombatFx:spriteState(unit, size)
    local r = self.units[unit]
    local offX, offY = 0, 0
    local rot, sx, sy = 0, 1, 1
    if r then offX, offY = self:slideOffset(unit, size) end

    -- A unit is either travelling or standing; MOVE and IDLE are the two loops that answer that, and
    -- they are mutually exclusive so their two vertical sines can never beat against each other.
    local moving = r and r.slideT and r.slideDur and not r.slideHold

    -- IDLE -- what a body does when nothing is being done to it. Floats, swells a touch at the top of
    -- the breath, sways slowly at half that rate so the two never line up into a bounce. Applies to
    -- every unit on the board, including one that has never acted and so has no reaction record at
    -- all: standing perfectly still is what made the old board read as a set of counters.
    if not moving and not (r and r.dying) then
        local ph = self:idlePhase(unit)
        local b = math.sin(self.clock * IDLE_RATE + ph) * 0.5 + 0.5 -- 0..1 over the breath
        offY = offY - IDLE_RISE * size * b
        sy = sy + IDLE_SWELL * b
        sx = sx - IDLE_SWELL * b * 0.5
        rot = rot + IDLE_TILT * math.sin(self.clock * IDLE_RATE * 0.5 + ph * 1.7)
    end

    -- MOVE -- the walk. slideOffset already carries the travel; this is what makes the travel read as
    -- WALKING: two footfalls per tile (contact at each end and at the midpoint), a rise between them,
    -- a squash on each contact and a stretch at each apex, and a lean into the direction of travel.
    -- Two steps per tile rather than one, because one hop per tile at this size reads as a bounce.
    if moving then
        local p = 1 - r.slideT / r.slideDur
        local swing = math.abs(math.sin(p * 2 * math.pi))
        offY = offY - MOVE_HOP * size * swing
        sy = sy + MOVE_SQUASH * (swing - 0.5)
        sx = sx - MOVE_SQUASH * (swing - 0.5) * 0.8
        -- The lean is a SCREEN direction, so the grid delta goes through :rotate first -- on a turned
        -- board a step to grid-east may be travelling screen-west, and the body must lean the way the
        -- player sees it going. Normalised, so a multi-tile rush leans no harder than a single step,
        -- and a step straight toward or away from the camera (no screen dx) leans not at all.
        local dx, dy = self:rotate((r.slideToX or unit.x) - r.slideFromX, (r.slideToY or unit.y) - r.slideFromY)
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 1e-4 then rot = rot + MOVE_LEAN * (dx / len) * swing end
    end

    -- ATTACK -- gather, strike, hold, recover (lungeCurve). The body also leans into the swing and
    -- stretches along it at extension, so the strike is carried by the whole body rather than being a
    -- rigid token sliding a third of a tile and back.
    if r and r.lungeT then
        local c = lungeCurve(1 - r.lungeT / LUNGE_TIME)
        local lx, ly = self:rotate(r.lungeDx * LUNGE_DIST * size * c, r.lungeDy * LUNGE_DIST * size * c)
        offX, offY = offX + lx, offY + ly
        local sdx = self:rotate(r.lungeDx, r.lungeDy) -- screen-space, and already normalised
        rot = rot + LUNGE_TILT * c * sdx
        local st = LUNGE_STRETCH * math.max(0, c)
        sx = sx + st
        sy = sy - st * 0.6
    end

    -- CAST -- the existing lean/hop, now with a GATHER under it: the body compresses over the first
    -- third of the clip and springs out of it as the ability leaves, so an activation reads as effort
    -- rather than a body drifting sideways while a glow happens to it.
    if r and r.castT then
        local p = 1 - r.castT / CAST_TIME
        local s = math.sin(p * math.pi) -- 0 at ends, 1 mid: out and back
        if r.castDx then -- aimed cast: thrust toward the target and settle
            local cx, cy = self:rotate(r.castDx * CAST_LEAN * size * s, r.castDy * CAST_LEAN * size * s)
            offX, offY = offX + cx, offY + cy
        else -- self/tile cast: a little upward hop instead
            offY = offY - CAST_BOB * size * s
        end
        local crouch = p < CAST_CROUCH and (1 - p / CAST_CROUCH) or 0
        sy = sy - CAST_SQUASH * crouch + CAST_SQUASH * 0.6 * s
        sx = sx + CAST_SQUASH * 0.7 * crouch - CAST_SQUASH * 0.4 * s
    end

    -- HIT -- thrown along the line the blow came in on, compressed by it, rocked back off it, and
    -- settling on a damped spring rather than easing politely home. Front-loaded on purpose: the
    -- displacement is at its greatest on the frame of impact, because that is the frame that has to
    -- say a blow landed.
    if r and r.knockT then
        local p = 1 - r.knockT / KNOCK_TIME
        local m = r.knockMag or 1
        local c = math.exp(-KNOCK_DECAY * p) * math.cos(p * KNOCK_RING)
        local kx, ky = self:rotate(r.knockDx * KNOCK_DIST * size * m * c, r.knockDy * KNOCK_DIST * size * m * c)
        offX, offY = offX + kx, offY + ky
        local squash = math.max(0, c) -- compressed on the way out, never inflated on the rebound
        sy = sy - KNOCK_SQUASH * m * squash
        sx = sx + KNOCK_SQUASH * m * squash * 0.8
        local sdx = self:rotate(r.knockDx, r.knockDy)
        rot = rot + KNOCK_TILT * m * c * sdx
    elseif r and r.shakeT then
        -- Damage with nobody behind it -- a Burn tick, a hazard, a trap -- has no line to recoil
        -- along, so it keeps the direction-blind jitter this file has always used. Screen-space on
        -- purpose (no :rotate): a rattle is about the picture, not the board.
        offX = offX + math.sin(r.shakeT * 90) * SHAKE_MAG * (r.shakeT / SHAKE_TIME)
    end

    -- DEATH -- the collapse under the dissolve. Accelerating, not eased: a body that has been killed
    -- gives way, it does not lower itself. It goes down on the side the last blow threw it toward,
    -- which is why knockDx outlives its own timer.
    if r and r.dying then
        local e = (1 - r.dying / DEATH_TIME) ^ 2
        local sdx = r.knockDx and self:rotate(r.knockDx, r.knockDy) or 0
        local side = sdx < 0 and -1 or 1
        rot = rot + DEATH_TILT * side * e
        offY = offY + DEATH_SINK * size * e
        sy = sy - DEATH_SQUASH * e
        sx = sx + DEATH_SQUASH * e * 0.5
    end

    local flash = (r and r.flashT) and (r.flashT / FLASH_TIME) or 0
    local fade = (r and r.dying) and (1 - r.dying / DEATH_TIME) or 0
    return offX, offY, flash, fade, rot, sx, sy
end

-- The additive cast glow for `unit`'s sprite: an amount 0..1 (0 = not casting) and its rgb. Peaks
-- mid-cast and fades at both ends, so the caster brightens as it looses the ability. Read as an extra
-- additive pass by the board's unit draw (ui/battle_map), separate from the reddish hit flash so the
-- caster and its victim glow in different colors.
function CombatFx:castGlow(unit)
    local r = self.units[unit]
    if not r or not r.castT then return 0, 0, 0, 0 end
    local g = math.sin((1 - r.castT / CAST_TIME) * math.pi) * CAST_GLOW
    local c = r.castColor or { 1, 1, 1 }
    return g, c[1], c[2], c[3]
end

-- The death fade of `unit` in 0..1 while it is animating out, or nil once it is not dying. Lets the
-- board keep drawing a fading corpse-to-be, and the turn strip fade its card out.
function CombatFx:deathFade(unit)
    local r = self.units[unit]
    if r and r.dying then return 1 - r.dying / DEATH_TIME end
    return nil
end

-- The value the HP bars should show for `unit` (lagging the model so the bar drains smoothly).
function CombatFx:displayHp(unit)
    local hp = unit.char and unit.char.stats and unit.char.stats.health
    local cur = hp and hp.current or 0
    local v = self.hp[unit]
    if v == nil then self.hp[unit] = cur; return cur end
    return v
end

-- Rumble offset (dx, dy px) for `unit`'s turn-strip card, driven by the same hit shake as the sprite
-- so the card jerks in sync with the blow. Zero when the unit isn't shaking.
function CombatFx:cardShake(unit)
    local r = self.units[unit]
    if not r or not r.shakeT then return 0, 0 end
    local p = r.shakeT / SHAKE_TIME -- decays 1 -> 0
    local dx = math.sin(r.shakeT * 90) * CARD_SHAKE_MAG * p
    local dy = math.cos(r.shakeT * 74) * CARD_SHAKE_MAG * 0.7 * p
    return dx, dy
end

-- Hit-flash amount (0..1) for `unit`'s turn-strip card, the same flash the sprite gets.
function CombatFx:cardFlash(unit)
    local r = self.units[unit]
    return (r and r.flashT and r.flashT / FLASH_TIME) or 0
end

-- Damage / heal numbers, drawn above their unit after the board. `map` supplies cell->pixel + size.
function CombatFx:drawFloaters(map)
    if #self.floaters == 0 then return end
    local size = map.size
    for _, f in ipairs(self.floaters) do
        local u = f.unit
        local wx, wy = map:cellToPixel(u.x, u.y)
        -- Ride the unit's slide: a number floating off a shoved body stays over the body, and stays
        -- over the tile it was STRUCK on for as long as the shove is held there (see setSlide).
        local sx, sy = self:slideOffset(u, size)
        wx, wy = wx + sx, wy + sy
        local p = f.age / f.life
        local a = 1 - p * p -- hold, then fade toward the end
        local font = f.big and self.bigFont or self.font
        love.graphics.setFont(font)
        local tw = font:getWidth(f.text)
        local x = wx + size / 2 - tw / 2 + (f.jx or 0)
        local y = wy + size * 0.28 - FLOAT_RISE * easeOut(p)
        love.graphics.setColor(0, 0, 0, 0.7 * a)
        love.graphics.print(f.text, x + 1, y + 1)
        love.graphics.setColor(f.color[1], f.color[2], f.color[3], a)
        love.graphics.print(f.text, x, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Debug: playing the animation set on demand
-- ---------------------------------------------------------------------------
--
-- The six clips are curves rather than authored art, which means the only way to judge one is to
-- watch it -- and waiting for a battle to happen to produce a heavy hit or a collapse is not
-- watching it, it is hoping for it. So the whole set can be fired at a chosen body from the board's
-- right-click debug menu (ui/panels/debug_menu.lua, "Animations"), on its own, in order, and slowly.
--
-- The header's rule about `fx.*` still holds and this does not break it: that rule is about the
-- per-cast EFFECT api inside models/combat.lua's resolveCast, which only exists mid-resolution. This
-- is the view-side controller poking its own reactions, which is exactly what it is for, and every
-- clip below is non-destructive -- the model is never touched, so a demonstrated death leaves a live
-- unit standing when the fade ends.

-- Play the set (or one clip of it) on `unit`. `target` aims everything that has a direction; pass nil
-- and a phantom one tile to the east stands in, which is enough for a body with the board to itself.
-- `clip` names one of "walk" / "attack" / "hit" / "heavy" / "cast" / "selfcast" / "death", or nil for
-- all of them in order, spaced so each has finished before the next begins.
local DEMO_ORDER = { "walk", "attack", "hit", "heavy", "cast", "selfcast", "death" }
local DEMO_GAP = { walk = 0.9, attack = 0.5, hit = 0.5, heavy = 0.6, cast = 0.6, selfcast = 0.6, death = 0.9 }

function CombatFx:demo(unit, target, clip)
    if not unit then return end
    target = target or { x = unit.x + 1, y = unit.y }
    local plays = {
        -- Slid in from the tile to the west, so the step reads without the model moving anywhere.
        walk = function() self:setSlide(unit, unit.x - 1, unit.y, 0.6) end,
        attack = function() self:lunge(unit, target) end,
        hit = function() self:hit(unit, 3, false, target) end,          -- a scratch: barely rocks it
        heavy = function() self:hit(unit, HEAVY_HIT * 2, false, target) end, -- and one that lands
        cast = function() self:cast(unit, target.x, target.y, false, false) end,
        selfcast = function() self:cast(unit, unit.x, unit.y, true, false) end, -- no aim: the hop
        death = function()
            self:hit(unit, HEAVY_HIT * 3, true, target)
            self:reaction(unit).dying = DEATH_TIME
        end,
    }
    if clip then
        if plays[clip] then plays[clip]() end
        return
    end
    local t = 0
    for _, name in ipairs(DEMO_ORDER) do
        self.demoQueue[#self.demoQueue + 1] = { t = t, fn = plays[name] }
        t = t + DEMO_GAP[name]
    end
end

-- Debug playback speed, 1 = real time. Anything slower is how a curve gets read: at full speed the
-- whole attack is sixteen frames and the wind-up inside it is three.
function CombatFx:setTimeScale(s)
    self.timeScale = math.max(0.05, math.min(4, s or 1))
end

-- Repeat one clip on `unit` for as long as the controller lives, once every `period` seconds. This is
-- what the Animation Gallery is made of (data/arenas/animation_gallery.lua, reached from the menu's
-- debug column): a body per clip, each one playing its own on a loop, so the whole set is on the
-- screen at once and can be compared rather than remembered.
--
-- Periods are chosen PER CLIP rather than shared, and deliberately do not divide into each other: a
-- rank that all fired together would be its own kind of lockstep, and the thing being looked at is
-- eight bodies that each read as a body.
function CombatFx:loopClip(unit, clip, target, period)
    if not (unit and clip) then return end
    self.loops[#self.loops + 1] =
        { unit = unit, clip = clip, target = target, period = period or 2, t = 0 }
end

return CombatFx


