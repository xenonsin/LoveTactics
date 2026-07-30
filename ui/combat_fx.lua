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
local LUNGE_TIME  = 0.20
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

local function easeOut(t) return 1 - (1 - t) * (1 - t) end

function CombatFx.new()
    local self = setmetatable({}, CombatFx)
    self.units = {}    -- unit -> { lungeT, lungeDx, lungeDy, shakeT, flashT, slideT, slideDur,
                       --           slideFromX, slideFromY, dying, dead }
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
local function strikeAngle(attacker, victim)
    if not (attacker and victim) then return 0 end
    local dx, dy = victim.x - attacker.x, victim.y - attacker.y
    if dx == 0 and dy == 0 then return 0 end
    return math.atan2(dy, dx)
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
local function playHit(amount, tags)
    local heavy = (amount or 0) >= HEAVY_HIT
    local motif = Motif.of(tags)
    local id = motif and ("battle.hit_" .. motif)
    if id and Sound.cues[id] then
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
            self:cast(e.unit, e.tx, e.ty, e.support)
            if e.unit == actor then actorCast = true end
            -- The activation itself makes a sound: the swing under an attack's impact, or an ability
            -- firing. Only offensive casts ring it -- a support cast (heal/buff) is announced by its own
            -- heal/buff cue below, so it would only double up here.
            if not e.support then Sound.play("battle.cast") end
            -- A friendly cast (a heal, a blessing) rises as motes off the caster; an offensive cast
            -- leaves its mark through the damage bursts its blows spawn, so it gets none here.
            if self.bursts and e.support then self.bursts:support(e.unit.x, e.unit.y, "motes") end
        elseif e.type == "damage" then
            local cell = struck[e.unit] or e.unit
            self:hit(e.unit, e.amount, e.lethal)
            -- A killing blow's audio is the "death" cue below, not a hit on top of it; a surviving blow
            -- rings its damage-type impact (see playHit).
            if not e.lethal then
                playHit(e.amount, e.tags)
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
                    { angle = strikeAngle(e.attacker, cell), lethal = e.lethal })
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
            -- A blow that was voided outright -- dodged, smoked, substituted (models/combat.lua). No
            -- damage number floats, so the sound is the only tell that the attack landed nothing.
            Sound.play("battle.miss")
        elseif e.type == "slide" then
            -- If this cue was pinned while it waited (see :pinSlides) the sprite is already sitting on
            -- its origin tile, so arming the real slide here picks up exactly where the pin left off
            -- rather than jumping back to it.
            self:forcedSlide(e.unit, e.fromX, e.fromY, e.hold and SHOVE_HOLD or nil)
        elseif e.type == "death" then
            self:reaction(e.unit).dying = DEATH_TIME
            Sound.play("battle.death")
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
function CombatFx:cast(unit, tx, ty, support)
    local r = self:reaction(unit)
    local dx, dy = (tx or unit.x) - unit.x, (ty or unit.y) - unit.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1e-4 then r.castDx, r.castDy = dx / len, dy / len
    else r.castDx, r.castDy = nil, nil end -- aimed at its own tile (self/tile cast): bob in place
    r.castT = CAST_TIME
    r.castColor = support and { 0.55, 0.95, 0.70 } or { 0.98, 0.82, 0.45 }
end

-- A blow landing on `unit`: shake + flash the sprite, float the number, jiggle its card. Damage
-- floats red (a brighter red on a killing blow); heals float green (see ingest).
function CombatFx:hit(unit, amount, lethal)
    local r = self:reaction(unit)
    r.shakeT = SHAKE_TIME
    r.flashT = FLASH_TIME
    self:floatText(unit, tostring(amount), lethal and { 1.0, 0.42, 0.38 } or { 0.95, 0.28, 0.26 }, lethal)
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
        if r.lungeT or r.castT or r.shakeT or r.flashT or r.dying or (r.slideT and r.slideGate) then return true end
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

-- Sprite draw modifiers for `unit` at tile size `size`: pixel offset (walk slide + attack lunge +
-- hit shake), a 0..1 white/red flash, and a 0..1 death fade (0 = untouched, 1 = fully faded out).
-- Pixel offset of `unit`'s in-flight slide from the tile the model has it on, or 0,0 when it is not
-- travelling. Split out from spriteState because the damage numbers need this ONE part of the sprite's
-- displacement and none of the rest: a floater rides along with a shoved body, but must not inherit
-- the hit shake or the attack lunge (a number that jitters is a number you can't read).
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
    return ((r.slideFromX - toX) * (1 - e) + (toX - unit.x)) * size,
           ((r.slideFromY - toY) * (1 - e) + (toY - unit.y)) * size
end

function CombatFx:spriteState(unit, size)
    local r = self.units[unit]
    if not r then return 0, 0, 0, 0 end
    local offX, offY = self:slideOffset(unit, size)
    if r.lungeT then
        local s = math.sin((1 - r.lungeT / LUNGE_TIME) * math.pi) -- 0 at ends, 1 mid: out and back
        offX = offX + r.lungeDx * LUNGE_DIST * size * s
        offY = offY + r.lungeDy * LUNGE_DIST * size * s
    end
    if r.castT then
        local s = math.sin((1 - r.castT / CAST_TIME) * math.pi) -- 0 at ends, 1 mid: out and back
        if r.castDx then -- aimed cast: thrust toward the target and settle
            offX = offX + r.castDx * CAST_LEAN * size * s
            offY = offY + r.castDy * CAST_LEAN * size * s
        else -- self/tile cast: a little upward hop instead
            offY = offY - CAST_BOB * size * s
        end
    end
    if r.shakeT then
        offX = offX + math.sin(r.shakeT * 90) * SHAKE_MAG * (r.shakeT / SHAKE_TIME)
    end
    local flash = r.flashT and (r.flashT / FLASH_TIME) or 0
    local fade = r.dying and (1 - r.dying / DEATH_TIME) or 0
    return offX, offY, flash, fade
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

return CombatFx


