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

local function easeOut(t) return 1 - (1 - t) * (1 - t) end

function CombatFx.new()
    local self = setmetatable({}, CombatFx)
    self.units = {}    -- unit -> { lungeT, lungeDx, lungeDy, shakeT, flashT, slideT, slideDur,
                       --           slideFromX, slideFromY, dying, dead }
    self.floaters = {} -- list of { unit, text, color, age, life, jx, big }
    self.pending = {}  -- beats waiting their turn: { t = seconds left, events = cue list }
    self.hp = {}       -- unit -> shown HP value, eased toward hp.current
    self.held = {}     -- unit -> how many pending beats still owe it a hit; its HP bar waits on them
    self.font = love.graphics.newFont(18)
    self.bigFont = love.graphics.newFont(24)
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
        end
    end
end

-- Does a beat still waiting to play owe `unit` something? True between the model resolving a blow and
-- the view getting round to showing it. The board reads it to keep drawing a unit the model has
-- already killed (and to hold its corpse token back) until the counter that felled it actually plays.
function CombatFx:awaiting(unit)
    return self.held[unit] ~= nil
end

-- Play one beat's worth of cues -- the reactions for a single blow and everything simultaneous with it.
function CombatFx:playBeat(events, actor)
    local firstTarget
    local actorCast = false -- did the acting unit already play a cast beat this batch?
    for _, e in ipairs(events) do
        if e.type == "cast" then
            self:cast(e.unit, e.tx, e.ty, e.support)
            if e.unit == actor then actorCast = true end
        elseif e.type == "damage" then
            self:hit(e.unit, e.amount, e.lethal)
            firstTarget = firstTarget or e.unit
            -- A blow struck by someone other than the acting unit -- a counter, a riposte, a thorns
            -- answer -- leans off its own cue, since the actor fallback below can't speak for it.
            if e.attacker and e.attacker ~= actor and e.attacker ~= e.unit then
                self:lunge(e.attacker, e.unit)
            end
        elseif e.type == "heal" then
            self:floatText(e.unit, "+" .. tostring(e.amount), { 0.55, 0.95, 0.60 })
        elseif e.type == "death" then
            self:reaction(e.unit).dying = DEATH_TIME
        end
    end
    -- The caster's own motion comes from its "cast" cue now. Fall back to the old damage-derived lunge
    -- only when the actor drew blood WITHOUT casting -- a counterattack or a reaction trait, which hits
    -- through no ability of its own -- so such a blow still leans toward the unit it hurt.
    if actor and not actorCast and firstTarget and actor ~= firstTarget then
        self:lunge(actor, firstTarget)
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
-- is already the destination cell.
function CombatFx:setSlide(unit, fromX, fromY, dur)
    local r = self:reaction(unit)
    r.slideFromX, r.slideFromY = fromX, fromY
    r.slideT, r.slideDur = dur, dur
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
        if r.slideT then
            r.slideT = r.slideT - dt
            if r.slideT <= 0 then r.slideT = nil; r.slideDur = nil end
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
        if r.lungeT or r.castT or r.shakeT or r.flashT or r.dying then return true end
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
function CombatFx:spriteState(unit, size)
    local r = self.units[unit]
    if not r then return 0, 0, 0, 0 end
    local offX, offY = 0, 0
    if r.slideT and r.slideDur then
        local e = easeOut(1 - r.slideT / r.slideDur)
        offX = offX + (r.slideFromX - unit.x) * size * (1 - e)
        offY = offY + (r.slideFromY - unit.y) * size * (1 - e)
    end
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
