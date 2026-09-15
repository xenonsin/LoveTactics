-- Right-side combat HUD: the turn-order strip (portraits + resource bars) and the current
-- character's item grid. Persistent (not a modal) and owned by states/battle.lua, which
-- routes input to it and feeds it a per-frame view via setView. Follows the project's
-- three-input standard: mouse hover/click on item slots here, while the battle state maps
-- keyboard number keys and the gamepad to the same arm/cancel actions.
--
-- Layout (per the design sketch): the turn-order strip fills the panel top-down but is
-- BOTTOM-aligned so the current turn sits just above the item grid at the very bottom.
-- The acting card is PINNED to the bottom -- it frames into the action grid below it, so it never
-- scrolls away. A long order (summons, big encounters) overflows the region ABOVE it, so that
-- region scrolls: `scroll` counts upcoming entries hidden off the bottom of it, i.e. how far
-- toward later turns the window has walked, while the current card stays put. Scroll re-anchors
-- to 0 (the nearest upcoming turns showing) whenever the turn changes.
--
--   local panel = CombatPanel.new(combat, {
--       onActivateItem = function(item, index) ... end,  -- slot clicked (arm / toggle)
--       onHoverItem    = function(item_or_nil) ... end,  -- hover changed (drives preview)
--       onInspectUnit  = function(unit) ... end,         -- turn-strip card clicked (read that body)
--   })
--   panel:setView({ order = {units}, current = unit, isPartyTurn = bool,
--                   items = {inventory}, armedItem = item_or_nil })
--   panel:draw(); panel:mousemoved(x, y); panel:mousepressed(x, y, button)
--   panel:wheelmoved(dx, dy)  -- caller gates on panel:contains(mouseX, mouseY)

local Scale = require("scale")
local Combat = require("models.combat")
local Item = require("models.item") -- for Item.costs: a cast may draw on more than one pool
local Trait = require("models.trait") -- for Trait.stackReadout: a passive charm's banked stacks
local Status = require("models.status") -- for waitNote: naming what a stance grants, not its id
local Hazard = require("models.hazard") -- likewise, for the ground a meditation lays
local AdjacencyLinks = require("ui.adjacency_links")
local StatusBadge = require("ui.status_badge")
local Glyphs = require("ui.glyphs")
local Colors = require("ui.colors")
local Theme = require("ui.theme")
local PoolCallout = require("ui.pool_callout")

local CombatPanel = {}
CombatPanel.__index = CombatPanel

-- 320 -> 352. See states/battle.lua's LEFT_W for the 184px of centring slack this comes out of.
--
-- It was 410 for one commit and that was too much. The width the panel actually needed is the width
-- its TEXT grew by -- the body floor went 12 -> 14, about a sixth -- not every pixel that happened to
-- be going spare. At 410 the panel was 0.80 of the board's own width and read as the heavier half of
-- the screen; the turn-order bars stretched into ribbons and the action slots grew margins rather
-- than content. 352 is 0.69, the two columns come out within 32px of each other, and the board keeps
-- 48 a side instead of being pinched to 24.
local PANEL_W = 352
CombatPanel.WIDTH = PANEL_W -- so states can reserve the same right-side margin
local SLIM_H = 34      -- a non-current turn card: small portrait, name, one thin HP bar (no numbers)
local CURRENT_H = 82   -- the acting unit's card: taller, larger portrait, full numbered HP/MP/SP
-- 6 -> 5, and the pixel buys a whole card. The band above the acting card is 270px on a desktop and a
-- slim card is 34, so at a 6px gap seven cards need 274 and the seventh was dropped four pixels short:
-- the strip showed the actor plus six. At 5 it needs 268 and fits, so the strip shows EIGHT turns --
-- the acting body and seven ahead of it. Nothing else changes; a pixel of air between cards is not
-- what was doing the work, and one more turn of the queue plainly is.
local ENTRY_GAP = 5   -- gap between slim cards (a little air, matching the mock's spacing)
local NUM_GUTTER = 20  -- left column holding each card's turn number, kept clear of the portrait
local INTENT_COL = 30  -- right column reserved on a foe's slim card for its predicted intent (icon + number)
local CURRENT_TOP_GAP = 34 -- room above the acting card for its "Current Turn" caption + breathing space
-- Item slots are rectangular (wider than tall) and kept compact so the turn-order
-- strip above them gets the bulk of the panel height.
-- 96 -> 100, which is the panel's own change (320 -> 352) carried through rather than a slot that
-- grew for its own sake: the grid is 3*100+12 = 312 inside 352, leaving 20 a side. It was briefly
-- 118, which made a slot noticeably wider than it is tall for no gain -- the icon is height-bound
-- either way (it scales to min((sw-8)/iw, (sh-8)/ih)), so all that width fell to the name band, and
-- a name band is not worth distorting the plate the whole grid is made of. The HEIGHT is unchanged.
local SLOT_W = 100      -- the DESKTOP slot; a narrower panel derives its own (see relayout)
local SLOT_MARGIN = 20  -- clear either side of the grid, so a narrow column still frames it
local SLOT_H = 58
local SLOT_GAP = 6
local COLS, ROWS = 3, 3
-- A slot badge's pill: side padding, the glyph's width, the gap before its number, and the pill's
-- height (see drawBadgeAt). Named because badgeSize measures a badge the same way, for a caller that
-- must place one itself.
-- ...on a DESKTOP. A handheld slot is 71px and its pill was 18 tall around a 9px glyph and
-- 12pt digits, which is what a cost and an initiative look like when they were sized for a
-- 96px slot with a name band under them. With the band gone (see drawSlot) the room is
-- there, so the badge takes it: see relayout, which is where these become per-panel.
local BADGE_PAD_X, BADGE_ICON_W, BADGE_GAP, BADGE_H = 5, 9, 3, 18
-- A pool-preview CALLOUT -- the projected value quoted as a floating pill pointing at the level the
-- bar will settle at -- is drawn by ui/pool_callout.lua, the one blueprint the hover tooltip's pool
-- stack uses too. This panel just queues its projections into a collector (self.poolCallouts) and
-- floats them after the cards, so two pools changing at once stack clear of each other instead of
-- colliding inside the 13px row pitch the bars are packed at.
local SCROLL_STEP = 1 -- turn-strip entries per wheel notch (entries are tall; one reads best)
-- HOW FAST A HAND-OFF READS, and it is paced to be FOLLOWED rather than to be over. The one thing
-- this strip exists to let a player do is pick a card, watch it move, and never lose it -- so these
-- are bounded below by what an eye can track, not above by what a fast player would prefer.
--
-- They were briefly halved (16 / 20 / 20), on the argument that 0.79s of card motion is a lot to pay
-- on every one of six turns a round. It is, and it bought nothing worth having: at that pace a card
-- crossing three ranks is a blur between two stills, which is the whole of what the strip is for.
local CARD_SPEED = 12 -- exponential ease rate of a card sliding to its new slot as the order reshuffles
-- A GHOST SLIDES TOO, and faster. It used to be drawn straight at whatever slot the layout gave it
-- this frame, which made every reflow a collision: the real cards eased toward their new ranks over a
-- fifth of a second while the hypotheticals stood still, so a card slid THROUGH a ghost on its way
-- past -- two plates and two names in one 34px row, every time the queue moved. Easing both means the
-- whole strip interpolates between two layouts that are each collision-free, rather than half of it
-- moving against the other half. Faster than a card because an aim ghost tracks the cursor, and a
-- slot that lags the thing it is previewing is worse than one that snaps.
local GHOST_SPEED = 18
-- ...and the GROWTH is quicker than the travel, deliberately. A card crossing the strip is the thing
-- being followed and wants time; a card changing SIZE in place is not going anywhere and reads the
-- moment it starts. 14 put it at 0.38s, which on top of the wait above made the arrival feel like the
-- slowest thing on screen.
local PROM_SPEED = 24 -- ease rate of a card's prominence (slim <-> tall current) as the turn passes
local SOLIDIFY_SPEED = 10 -- ease rate a just-committed preview ghost solidifies into its real card

-- THE QUEUE IS AN EVENLY PITCHED LIST, and it was briefly not. A pass spaced the cards by the WAIT
-- between them -- a foe a hair behind you hugging your card, one seven ticks out sitting adrift --
-- and drew a hairline rail of whole-tick marks beside them to measure it against. The arithmetic was
-- sound and it read badly: gaps that size are noise rather than a scale, the rail was a graph down
-- the side of a thing nobody reads as a graph, and on the short strip a handheld gets the air cost a
-- whole card of queue. Reverted on sight of it running. The WAIT figure each card carries
-- (drawInitiative) is what answers "how long until this one moves", and it does it in one place
-- instead of two.
-- An initiative that moved without the order moving: how big a change counts (ticks), and how long
-- the card's pulse runs. See update's tempo pass.
local POOL_PITCH = 13 -- row pitch of the acting card's HP/MP/SP stack, at its full height
-- How long a felled body's card may be held waiting for a death cue that has not arrived. Generous
-- against the longest approach walk a carried blow can take, and finite so nothing is stranded.
-- How fast the strip's own clock catches up with the model's after a turn is taken. See shownClock:
-- slow enough that the count-down is a thing you watch happen rather than a set of numbers that were
-- already different the next time you looked, and no slower -- it is the last thing holding the strip
-- before the next body may act.
local CLOCK_SPEED = 10
-- The backstop on stage one: however long the acting card takes to reach its rank, the clock is not
-- held past this. Comfortably longer than the slide itself at CARD_SPEED.
local OUT_MAX = 1.2
local DEATH_HOLD_MAX = 4
local TEMPO_EPS = 0.25
local TEMPO_PULSE = 0.45

-- Frame-rate-independent exponential approach toward `target` (stable regardless of frame time), and a
-- plain linear blend. Used for every turn-strip tween so the animation feels the same at any FPS.
local function approach(cur, target, k, dt) return cur + (target - cur) * (1 - math.exp(-k * dt)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

-- Resource bars drawn per turn-strip entry, in order (skipped when a resource's max is 0). Health
-- has no fixed colour: it's filled with the unit's SIDE colour (blue ally / red foe), so a card's
-- HP bar says whose unit it is the same way the board token's does. Resolved per unit by barColor.
local RESOURCES = {
    { key = "health" },
    { key = "mana",    color = Colors.MANA },
    { key = "stamina", color = Colors.STAMINA },
}

-- The fill colour for `unit`'s `key` pool -- the side colour for health, the pool's own otherwise.
-- A method rather than a bare local so the health case can go through :unitColor and inherit the
-- held-allegiance read with everything else that paints a body.
function CombatPanel:barColor(res, unit)
    return res.color or self:unitColor(unit)
end

-- Short tag drawn beside each turn-strip bar (tinted with the pool colour), so a bar reads without
-- relying on colour alone -- and so the value beside it isn't mistaken for a different pool.
local BAR_LABELS = { health = "HP", mana = "MP", stamina = "SP" }

-- Cost badge tint per resource stat (falls back to a neutral grey for anything else). Health is
-- PARTY blue rather than a colour of its own: a cost badge only ever prices the player's own actor,
-- whose HP bar is blue, so "this spends your health" reads in the colour that health already has.
local RES_COLOR = { health = Colors.PARTY, mana = Colors.MANA, stamina = Colors.STAMINA }
local COST_FALLBACK = { 0.75, 0.75, 0.80 }
local SPEED_COLOR = { 0.865, 0.707, 0.341 } -- gold, matching the timeline/initiative accent
local WARN_COLOR = { 0.789, 0.361, 0.354 }  -- red cost badge on an ability the actor can't afford
local COUNTER_COLOR = { 0.568, 0.414, 0.786 } -- lavender charge badge: what a purse item currently holds

-- How far the ray at angle `a` travels from a rectangle's centre before it meets the rectangle's
-- edge, given the half-extents. What makes the cooldown wedge below fill its slot corner-to-corner
-- without spilling: every vertex lands ON the boundary, so no clipping is needed. (A scissor can't do
-- this job here -- love.graphics.setScissor takes real window pixels, while everything in this file is
-- authored in the 1280x720 logical space, see scale.lua.)
local function edgeRadius(a, hw, hh)
    local c, s = math.abs(math.cos(a)), math.abs(math.sin(a))
    return math.min(c > 1e-6 and hw / c or math.huge, s > 1e-6 and hh / s or math.huge)
end

-- The cooldown clock over a slot whose reflex is spent: a dark wedge covering the share of the
-- cooldown still to run, sweeping clockwise from 12 o'clock and shrinking away as the reflex comes
-- back. Just the wedge: the ticks left ride in an hourglass badge its caller centres on it (see
-- drawItemGrid), so this stays a shape and the count stays a badge like every other number in a slot.
--
-- Drawn as a triangle fan over the slot RECTANGLE rather than one pie polygon, for two reasons: a
-- sector closes on itself at a full turn (the frame a fresh cooldown starts on) and love.math.triangulate
-- rejects that, and a fan lets each vertex ride the rectangle's edge. The rect's four corner angles are
-- folded into the sample list so a fan segment never cuts across one and leaves a corner uncovered.
local COOLDOWN_TINT = { 0.05, 0.06, 0.09, 0.66 }
local COOLDOWN_STEPS = 24 -- samples per full turn; the corners are added on top of these
local function drawCooldownSweep(x, y, w, h, frac)
    frac = math.max(0, math.min(1, frac))
    local cx, cy, hw, hh = x + w / 2, y + h / 2, w / 2, h / 2
    local a0 = -math.pi / 2                  -- 12 o'clock
    local a1 = a0 + 2 * math.pi * frac       -- clockwise: +y is down, so the sweep runs the right way

    local angles = {}
    for i = 0, COOLDOWN_STEPS do
        local a = a0 + (a1 - a0) * (i / COOLDOWN_STEPS)
        angles[#angles + 1] = a
    end
    for _, corner in ipairs({ math.atan2(hh, hw), math.atan2(hh, -hw),
                              math.atan2(-hh, -hw), math.atan2(-hh, hw) }) do
        -- atan2 answers in (-pi, pi]; lift the corner into the sweep's own range before testing it.
        while corner < a0 do corner = corner + 2 * math.pi end
        if corner < a1 then angles[#angles + 1] = corner end
    end
    table.sort(angles)

    love.graphics.setColor(COOLDOWN_TINT)
    for i = 2, #angles do
        local pa, na = angles[i - 1], angles[i]
        local pr, nr = edgeRadius(pa, hw, hh), edgeRadius(na, hw, hh)
        love.graphics.polygon("fill", cx, cy,
            cx + math.cos(pa) * pr, cy + math.sin(pa) * pr,
            cx + math.cos(na) * nr, cy + math.sin(na) * nr)
    end
end

-- Draw a resource bar with an optional preview `delta` (an aimed action's projected change): the
-- "after" fill in the pool colour, then the lost slice in red (delta < 0, brighter when lethal) or
-- the gained slice in green (delta > 0) beside it. Mirrors ui/tile_tooltip.lua's bar so the banner
-- preview reads the same as the tooltip. No delta = a plain fill.
-- `reserved` (a share of the pool committed to sustaining a summon) is carved off the far end as a
-- dimmed tail; the track still spans the pool's true maximum, so the usable fill visibly shrinks.
-- `alpha` (default 1) fades the whole bar, so a turn-strip card can cross-fade its slim HP bar out as
-- the full pool stack fades in while it grows into the frame.
-- `notches` (optional, the last argument) is a list of health fractions to tick the bar at -- a boss's
-- phase thresholds, read off its own relic (Combat.bossThresholds). The same marks the board's heavy
-- bar wears (ui/battle_map.lua's drawHpBar) and drawn to the same recipe, so a player reading the
-- strip and a player reading the board are reading one instrument in two places: a notch still ahead
-- of the fill stands in bone, one already crossed goes dark and stays drawn.
--
-- Read off `ratio`, the drawn fill, and never off the model's true current -- which on this card lags
-- behind a hit on purpose (shownHealth). Blackening a notch the instant the model crossed it would
-- announce the stage a beat before the blow that bought it had played.
local function drawResourceBar(x, y, w, h, cur, max, color, delta, lethal, reserved, alpha, notches)
    delta = delta or 0
    alpha = alpha or 1
    local ratio = (max > 0) and math.max(0, math.min(1, cur / max)) or 0
    Theme.set(Theme.barTrack, 0.9 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    if reserved and reserved > 0 and max > 0 then
        local resW = w * (reserved / max)
        love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.7 * alpha)
        love.graphics.rectangle("fill", x + w - resW, y, resW, h, 2, 2)
    end
    if delta ~= 0 and max > 0 then
        local afterRatio = math.max(0, math.min(1, (cur + delta) / max))
        if delta < 0 then
            love.graphics.setColor(color[1], color[2], color[3], 0.95 * alpha)
            love.graphics.rectangle("fill", x, y, w * afterRatio, h, 2, 2)
            -- The slice about to be lost is amber, not red: on an enemy's red HP bar a red slice
            -- would be invisible. Reads against every pool colour.
            local loseCol = lethal and Colors.LETHAL or Colors.PENDING
            love.graphics.setColor(loseCol[1], loseCol[2], loseCol[3], 0.95 * alpha)
            love.graphics.rectangle("fill", x + w * afterRatio, y, w * (ratio - afterRatio), h, 2, 2)
        else
            love.graphics.setColor(color[1], color[2], color[3], 0.95 * alpha)
            love.graphics.rectangle("fill", x, y, w * ratio, h, 2, 2)
            local gain = Colors.HEALING
            love.graphics.setColor(gain[1], gain[2], gain[3], 0.9 * alpha)
            love.graphics.rectangle("fill", x + w * ratio, y, w * (afterRatio - ratio), h, 2, 2)
        end
    else
        love.graphics.setColor(color[1], color[2], color[3], 0.95 * alpha)
        love.graphics.rectangle("fill", x, y, w * ratio, h, 2, 2)
    end
    for _, at in ipairs(notches or {}) do
        local nx = math.floor(x + w * at) + 0.5
        love.graphics.setColor(0, 0, 0, 0.85 * alpha)
        love.graphics.line(nx, y, nx, y + h)
        if ratio > at then -- still standing: the stage has not been bought yet
            Theme.set(Theme.ink, 0.9 * alpha)
            love.graphics.line(nx + 1, y, nx + 1, y + h)
        end
    end
    -- A hairline sepia outline so the fill doesn't bleed into the light parchment (see ui/theme.lua).
    Theme.set(Theme.barOutline, (Theme.barOutline[4] or 1) * alpha)
    love.graphics.rectangle("line", x, y, w, h, 2, 2)
end

-- Does this fight have a bench to rotate with? Only a campaign battle does; a duel, a draft and a

function CombatPanel.new(combat, opts)
    opts = opts or {}
    local self = setmetatable({}, CombatPanel)
    self.combat = combat
    self.onActivateItem = opts.onActivateItem
    self.onHoverItem = opts.onHoverItem
    self.onHoverUnit = opts.onHoverUnit
    self.onWait = opts.onWait -- the long Wait/Focus/Defend button under the item grid
    self.onInspectUnit = opts.onInspectUnit -- a turn-strip card clicked: read that body

    -- Chrome wears the display face (Theme.display -> the engraved serif, falling back to the default
    -- until the ttf lands); dense numeric read-outs stay on the plain body face for legibility.
    self.headFont = Theme.display(16)
    self.nameFont = Theme.display(14)
    self.smallFont = Theme.body(12)
    self.captionFont = Theme.display(12) -- section captions (Current Turn / Actions) wear the serif, matching Turn Order
    -- (item names in a grid slot fit a native sans via Theme.fitText -- see drawSlot; never scaled)

    self:relayout(opts.width)

    self.view = { order = {}, items = {}, isPartyTurn = false }
    self.hoverIndex = nil
    self.hoverUnit = nil
    self.scroll = 0 -- turn-strip entries scrolled off the bottom (0 = the actor is at the bottom)
    self.poolCallouts = PoolCallout.new() -- projections queued by drawPoolBars, floated after the cards
    -- Turn-strip animation (fed by update): each card's eased Y so it slides to its new slot as the
    -- order reshuffles, plus the bookkeeping to fade a just-fallen unit's card out in place.
    self.cardY = {}       -- unit -> eased Y
    self.cardProm = {}    -- unit -> eased prominence 0..1 (1 = the tall framed current card)
    self.lastLayout = {}  -- unit -> { entry, y, h } last laid out, to seed a fading card
    self.dyingCards = {}  -- unit -> { entry, y, h } fading to black on death
    -- ...and the reason it is being held there. A body leaves the turn order the INSTANT the model
    -- fells it, which can be a third of a second before the blow that felled it is seen to play, so
    -- "has the fade started" is the wrong question to hold its card on -- for that whole window the
    -- answer is no and the card simply vanishes, then the death animates on an empty row. The right
    -- question is the model's: it is dead, so hold the card until a fade has actually run its course.
    self.deathHold = {}   -- unit -> { seenFade = bool, t = seconds held }
    -- THE STRIP'S OWN CLOCK, lagging the model's. Taking a turn does two things at once and only one
    -- of them is a reorder: endTurn adds the action's cost to the actor (which moves it down the
    -- queue), and Combat.rebase then subtracts the new minimum from EVERYONE so the next body sits at
    -- 0. Subtracting the same figure from every unit cannot change anybody's rank -- it is a clock
    -- advancing, banked in combat.clock -- but it does change every number on screen at once.
    --
    -- Landing both on the same frame is what made the preview read as a lie: the ghost promises "you
    -- act at 4.0", the card lands in exactly the promised place, and the number on it says something
    -- else because the whole field counted down underneath it in the same instant. So the panel keeps
    -- its own clock and shows `initiative + (clock - shownClock)`: held back, that is the figure the
    -- ghost promised and every other card is untouched; eased forward, every number counts down
    -- together and the next body arrives at 0.0. The cost lands first, then time passes -- which is
    -- the order they actually happen in, and now the order they are seen in.
    self.shownClock = nil -- nil until the first view; then a value trailing combat.clock
    -- On a turn advance the outgoing actor's card MORPHS in place at its preview ghost's slot -- content
    -- fading up from the ghost -- rather than sweeping the tall card through the list. wasCurrent tracks
    -- who held the frame so the hand-off fires exactly once.
    self.solidify = {}    -- unit -> { t = 1..0, dashed = bool }, the ghost's dashes dissolving as the
                          -- card that was promised that slot arrives in it
    self.lastGhostY = {}  -- unit -> on-screen Y of its SOONEST preview ghost, so a hand-off knows the
                          -- card is arriving at a slot a ghost was holding and can dissolve it
    self.wasCurrent = nil -- the unit that held the framed slot last frame
    -- A turn advance plays out in two STAGES, and they are the two things the model does:
    --   "out" -- THE COST LANDS. The acting card leaves the frame and travels to the rank its action
    --            bought, shrinking to a slim card as it goes. The strip's clock is HELD here, so every
    --            figure on screen still reads the wait the preview quoted.
    --   "in"  -- TIME PASSES. The clock catches up: every wait counts down together, and the next body
    --            reaches 0.0 and takes the frame.
    -- Which is the order they happen in (endTurn charges the cost, THEN Combat.rebase advances the
    -- clock) and now the order they are seen in. (Hit reactions finish earlier still: the battle state
    -- holds the advance until fx settles.)
    self.phase = "idle"    -- "idle" | "out" | "in"
    self.outgoingUnit = nil -- the actor leaving the frame during "out"
    -- NOTHING IS EVER HELD STILL. A hand-off used to freeze the whole strip for its first phase so
    -- the outgoing card's morph played against a picture that was not moving -- which made sense only
    -- while that card APPEARED at its destination instead of travelling to it. It travels now, and a
    -- freeze is precisely what would stop it. What the freeze was really guarding against -- a ghost
    -- placed against the new ranking while the cards still sat at the old one -- is answered instead
    -- by easing the ghosts too (GHOST_SPEED): every row interpolates between the same two layouts, so
    -- none of them is ever pinned against the others and there is nothing left to hold still.
    -- A tempo change that does NOT reorder anybody: every unit's initiative shifts by the same amount
    -- on a rebase, so a unit whose shift DIFFERS from the field's is one something actually moved
    -- (a stun's shove, a hasten's cut). Those get a pulse; the shared rebase gets nothing.
    self.lastInit = {}     -- unit -> initiative as of last frame
    self.tempo = {}        -- unit -> { t = TEMPO_PULSE..0, dir = "sooner"|"later" }
    -- Eased Y per PREVIEW slot, the ghost/repeat counterpart of cardY. Keyed unit -> nth ghost of
    -- that unit this frame, because one body can hold several at once (a channeled cast previews the
    -- slot it resolves at AND the slot its caster next acts from, and a repeat slot may sit past both).
    self.ghostY = {}
    return self
end

-- The HP value the strip should show for `unit`: the fx controller's lagging value (so a strip HP
-- bar drains in step with the board) when one is wired, else the true current.
function CombatPanel:shownHealth(unit)
    if self.fx then return self.fx:displayHp(unit) end
    return unit.char.stats.health.current
end

-- The colour the strip should draw `unit` in -- its side, except while a Charm has flipped it in the
-- model and the blow that turned it has not yet been seen to land, when it keeps the colours it was
-- taken from (ui/combat_fx.lua shownAllegiance). The strip asks the same question the board does, off
-- the same hold, so a body does not change hands on one surface a beat before the other. Falls back
-- to the live side when no fx controller is wired, exactly as :shownHealth does.
function CombatPanel:unitColor(unit)
    if self.fx then return self.fx:unitColor(unit) end
    return Colors.unit(unit)
end

-- Is `unit` drawn as ONE OF OURS right now? The same held read, for the places that branch on faction
-- rather than paint with it -- notably the enemy-intent icon, which on an unheld read would announce a
-- charm a whole beat before the touch that laid it, on the very card the player is watching.
-- The wait to PRINT for a model initiative: its own figure plus however far the strip's clock is
-- still behind the fight's. Zero difference at rest, so this is the model's own number every frame
-- that is not a hand-off.
function CombatPanel:shownWait(initiative)
    local clock = (self.combat and self.combat.clock) or 0
    return (initiative or 0) + (clock - (self.shownClock or clock))
end

function CombatPanel:shownParty(unit)
    if self.fx then return (self.fx:shownAllegiance(unit)) == "party" end
    return unit.side == "party"
end

-- The current-turn (tall) card is a FIXED anchor -- it never slides or grows; whoever is acting simply
-- occupies it. The motion is all in the queue: the outgoing actor's preview ghost MORPHS in place into
-- its real card (solidify), and the other upcoming cards slide to their new ranks. A unit that just died
-- keeps a card fading to black (dyingCards) until its death fade ends. The battle state holds the next
-- auto-turn until this settles (cardsSettled).
function CombatPanel:update(dt)
    local current = self.view.current
    self.time = (self.time or 0) + dt -- drives the log-highlight pulse, in step with the board's

    -- Cache each preview ghost's on-screen Y (sticky until the unit next acts, so it survives the hold
    -- beat). A hand-off solidifies the outgoing card at THIS slot -- an empty preview slot in the frozen
    -- old layout -- so it never collides with a held card, and only a unit that had a preview morphs.
    -- THE SOONEST ONE, not the last seen. A body can hold several hypotheticals at once -- a channeled
    -- cast previews the slot it resolves at AND the slot its caster next acts from -- and the slot the
    -- card actually lands in when the turn ends is the EARLIEST of them. This loop walks the strip
    -- bottom-up, so it used to overwrite its way to the latest instead, and the card solidified at a
    -- slot the unit does not reach for another turn. (It also put the card on top of the ghost still
    -- standing there, which is how it was found.)
    local firstGhost = {}
    for _, e in ipairs(self:entryLayout()) do
        local u = e.entry.preview and e.entry.unit
        if u and not firstGhost[u] then
            firstGhost[u] = true
            self.lastGhostY[u] = e.y
        end
    end

    -- Turn advanced. THE ACTING CARD LEAVES THE FRAME ON ITS OWN FEET: it eases from the frame up to
    -- the rank its cost bought, shrinking from the tall plate to a slim one as it goes, so the card a
    -- player is most likely to be watching is one they can actually follow out.
    --
    -- It used to be MOVED THERE INSTANTLY -- cardY assigned to the ghost's slot, prominence assigned
    -- to 0 -- while a copy of the big card stayed behind in the frame fading out. The argument was
    -- that a full-height plate sweeping up through the queue looks wrong, and it does; but the cure
    -- was a card that never travelled, and measured against a running fight it was a 188px jump on
    -- every single turn. Shrinking it AS it travels answers both: nothing full-height ever crosses the
    -- queue, and nothing teleports. Both tweens were already here; all that was needed was to stop
    -- overwriting them.
    if current ~= self.wasCurrent then
        local out = self.wasCurrent
        self.arrivedCurrent = nil -- a new turn is landing; nothing has come to rest in it yet
        if out then
            self.outgoingUnit = out
            -- The dashed border of the ghost it is arriving at dissolves as it lands, so the card is
            -- seen to take the slot the preview promised. Its CONTENT no longer fades up from nothing:
            -- the card was already on screen a moment ago and is simply somewhere else now.
            self.solidify[out] = { t = 1, dashed = self.lastGhostY[out] ~= nil }
            self.phase = "out"
            self.lastGhostY[out] = nil
        else
            self.phase, self.outgoingUnit = "idle", nil
        end
        if current then self.lastGhostY[current] = nil end -- fresh turn: drop any stale ghost slot
        self.wasCurrent = current
    end

    local layout = self:entryLayout()

    -- Prominence: non-current cards decay to slim. The incoming current is held slim through "out",
    -- grows through "in", and sits full at "idle" -- so the big card only inflates as it drops in.
    for u, p in pairs(self.cardProm) do
        if u ~= current then
            local np = approach(p, 0, PROM_SPEED, dt)
            self.cardProm[u] = (np < 0.01) and nil or np
        end
    end
    if current then
        -- THE ARRIVING CARD GROWS FROM THE FIRST FRAME OF THE HAND-OFF, not from the end of it. It
        -- used to be pinned flat at 0 for the whole of stage one, so nothing happened to it at all
        -- while the outgoing card travelled -- and only then did it begin. That dead wait read as the
        -- growth being slow when the growth had not started: a fifth of a second of nothing, then the
        -- tween. There is no longer anything to wait for. The card leaving the frame is travelling out
        -- of it and shrinking as it goes, so the two can happen together: the frame is vacated and
        -- filled in one movement, which is what a hand-over looks like.
        if self.phase == "idle" then self.cardProm[current] = 1
        else self.cardProm[current] = approach(self.cardProm[current] or 0, 1, PROM_SPEED, dt) end
    end

    local present = {}
    local moving = false
    -- Has the acting card finished travelling to the rank its cost bought? Stage one ends on this.
    --
    -- TRUE UNTIL SOMETHING SAYS OTHERWISE. It was seeded `self.outgoingUnit == nil`, which is false
    -- for every hand-off that has one -- and the loop below only ever clears it, never sets it. So it
    -- could not become true while a card was leaving, stage one always ran to its backstop, and the
    -- clock sat frozen for a second before it began to count down. Measured: cards at rest by +0.64s,
    -- clock still untouched at +1.04s, settled at +1.78s.
    local outSettled = true
    -- Ghost slots are numbered per unit as the layout is walked, and the number is stashed on the
    -- entry so the draw pass keys the same slot the ease did (both read one entryLayout, off one
    -- view.order, in one frame).
    local ghostSeen, ghostN = {}, {}
    for _, e in ipairs(layout) do
        if e.entry.preview then
            local u = e.entry.unit
            local n = (ghostN[u] or 0) + 1
            ghostN[u] = n
            e.entry.ghostSlot = n
            local slots = self.ghostY[u]
            if not slots then slots = {}; self.ghostY[u] = slots end
            ghostSeen[u] = ghostSeen[u] or {}
            ghostSeen[u][n] = true
            -- A slot appearing for the first time lands where it belongs: a ghost has no history to
            -- slide from, and easing it up from nothing would read as a card arriving.
            --
            -- A GHOST KEEPS EASING THROUGH "out", where the cards are held. That looks like a hole in
            -- the freeze and is the opposite: the frozen layout is a STILL target, so a ghost caught
            -- halfway past a card when the hand-off began finishes its move and clears it, instead of
            -- stopping dead on top of it for the whole phase -- which is the very stack this pass
            -- exists to remove, just arrived at from the other direction.
            if slots[n] == nil then
                slots[n] = e.y
            else
                local ny = approach(slots[n], e.y, GHOST_SPEED, dt)
                -- A ghost in flight counts as the strip MOVING, the same as a card. It is not
                -- cosmetic bookkeeping: a hand-off that begins while a hypothetical is still sliding
                -- past a card freezes the two mid-crossing and holds them overprinted for the whole
                -- phase, which is how the last of these collisions survived.
                if math.abs(e.y - ny) > 0.5 then moving = true end
                slots[n] = ny
            end
        else
            local u = e.entry.unit
            present[u] = true
            self.lastLayout[u] = { entry = e.entry, y = e.y, h = e.h, w = e.w, x = e.x }
            if self.cardY[u] == nil then self.cardY[u] = e.y end
            -- Ease toward the new layout, always. This is the whole of how a card gets anywhere.
            local ny = approach(self.cardY[u], e.y, CARD_SPEED, dt)
            local far = math.abs(e.y - ny) > 0.5
            if far then moving = true end
            self.cardY[u] = ny
            if u == self.outgoingUnit and (far or (self.cardProm[u] or 0) > 0.05) then
                outSettled = false
            end
        end
    end

    for u, sd in pairs(self.solidify) do
        sd.t = approach(sd.t, 0, SOLIDIFY_SPEED, dt)
        if sd.t < 0.02 then self.solidify[u] = nil else moving = true end
    end
    for u, p in pairs(self.cardProm) do if u ~= current and p > 0.02 then moving = true end end

    -- Stage one is over when the acting card has ARRIVED -- when the cost it paid has been seen to
    -- move it -- rather than when some fade happens to run out. `outSettled` is measured in the layout
    -- loop above against the card itself. The cap is a backstop: a card whose target keeps moving (a
    -- summon arriving mid-hand-off) must not hold the clock for ever.
    if self.phase == "out" then
        moving = true
        self.outT = (self.outT or 0) + dt
        if outSettled or self.outT > OUT_MAX then
            self.phase = "in"
            self.outT = nil
        end
    elseif self.phase == "in" then
        if current and (self.cardProm[current] or 0) < 0.995 then moving = true end
        if not moving then self.phase = "idle" end
    end

    -- A unit that just left the order: hold its card while the blow that felled it is still to be
    -- SEEN. Asked of the model (`alive`) rather than of the fx controller, because the two disagree
    -- for as long as a third of a second: the model fells a body and drops it from the order at once,
    -- while the cue that plays the death can still be sitting undrained behind an approach walk. Held
    -- on "has the fade started" the card blinked out for that whole window and the death then
    -- animated on a row with nothing in it -- measured at 19 and 20 frames in two fights out of four.
    for u in pairs(self.cardY) do
        if not present[u] then
            local felled = (u.alive == false) or (self.fx and (self.fx:deathFade(u) or self.fx:awaiting(u)))
            if felled and self.lastLayout[u] then
                self.dyingCards[u] = self.lastLayout[u]
                self.deathHold[u] = self.deathHold[u] or { seenFade = false, t = 0 }
            end
            self.cardY[u] = nil
        end
    end
    -- ...and let it go once the fade has been seen to RUN and then finish. A fade that has not
    -- started yet is not a fade that is over, which is the whole distinction the old test missed.
    -- DEATH_HOLD_MAX is the backstop: a cue that never arrives (a body removed by something that
    -- raises none) must not strand a card on the strip for the rest of the fight.
    for u, h in pairs(self.deathHold) do
        -- Back on its feet (a revive, a rotation returning a body): it is in the order again and owns
        -- a live card, so the held one has to go at once rather than linger behind it until the
        -- backstop expires.
        if present[u] then
            self.dyingCards[u] = nil
            self.deathHold[u] = nil
        else
        h.t = h.t + dt
        local fade = self.fx and self.fx:deathFade(u)
        if fade then h.seenFade = true end
        local waiting = self.fx and self.fx:awaiting(u)
        if (h.seenFade and not fade) or (h.t > DEATH_HOLD_MAX and not fade and not waiting) then
            self.dyingCards[u] = nil
            self.deathHold[u] = nil
        end
        end
    end
    for u in pairs(self.lastLayout) do
        if not present[u] and not self.dyingCards[u] then self.lastLayout[u] = nil end
    end
    -- Drop the eased Y of any ghost slot that is no longer in the order, so a unit that loses its
    -- second hypothetical does not hand that slot's stale position to a later one.
    for u, slots in pairs(self.ghostY) do
        local seen = ghostSeen[u]
        if not seen then self.ghostY[u] = nil
        else for n in pairs(slots) do if not seen[n] then slots[n] = nil end end end
    end

    -- THE CLOCK ADVANCES IN THE SECOND STAGE, never the first. Through "out" the outgoing card is
    -- still travelling to the slot its ghost promised, so the numbers are held exactly as the preview
    -- quoted them; once that has landed, time is allowed to pass and every figure counts down to the
    -- new basis together. A first view (or a fight that jumps its clock, a wave arriving) snaps rather
    -- than counting down from nowhere.
    local clock = (self.combat and self.combat.clock) or 0
    if self.shownClock == nil or math.abs(clock - self.shownClock) > 60 then
        self.shownClock = clock
    elseif self.phase ~= "out" then
        self.shownClock = approach(self.shownClock, clock, CLOCK_SPEED, dt)
        -- Done once no DIGIT can still change: the figures are printed to one decimal, so a twentieth
        -- of a tick is under the resolution of the thing being animated. Chasing 0.02 held the strip
        -- for a third of a second after the last number had stopped moving.
        if math.abs(clock - self.shownClock) > 0.05 then moving = true end
    end

    self:trackTempo(dt, layout)


    -- Cards still sliding/growing (or a death card fading) means the reshuffle isn't done.
    self._cardsMoving = moving or (next(self.dyingCards) ~= nil)
    -- ...and the first frame it IS done, this body's turn has properly arrived. Latched, never
    -- re-tested -- see readyForPreview for what happens when it is asked live.
    if self.wasCurrent and not self._cardsMoving then self.arrivedCurrent = self.wasCurrent end
end

-- Take the snapshot phase "out" lays out from: last frame's entry list, with two substitutions that
-- A body whose initiative moved without the ORDER moving. Every unit shifts by the same amount when
-- Combat.rebase drops the field back to zero, so the field's own shift is the MEDIAN delta and only a
-- unit that deviates from it was actually moved by something -- a stun's shove, a hasten's cut. That
-- receipt, and now the ONLY one: the queue is evenly pitched, so a change that reorders nobody moves
-- no card at all and the figure is the single thing that can report it. Gold and brighter for sooner,
-- dim and smaller for later.
function CombatPanel:trackTempo(dt, layout)
    for u, tp in pairs(self.tempo) do
        tp.t = tp.t - dt
        if tp.t <= 0 then self.tempo[u] = nil end
    end

    local seen, deltas = {}, {}
    for _, e in ipairs(layout) do
        local entry = e.entry
        if not entry.preview and entry.initiative then
            local u = entry.unit
            seen[u] = entry.initiative
            local was = self.lastInit[u]
            if was then deltas[#deltas + 1] = entry.initiative - was end
        end
    end
    -- Two units is not a field to take a median of, and the frozen phases re-rank nothing anyway.
    if #deltas >= 3 and self.phase == "idle" then
        table.sort(deltas)
        local shift = deltas[math.floor(#deltas / 2) + 1]
        for u, init in pairs(seen) do
            local was = self.lastInit[u]
            local moved = was and (init - was - shift)
            if moved and math.abs(moved) > TEMPO_EPS and u ~= self.view.current
                and u ~= self.outgoingUnit then
                self.tempo[u] = { t = TEMPO_PULSE, dir = moved < 0 and "sooner" or "later" }
            end
        end
    end

    self.lastInit = seen
end

-- Have the turn-strip cards finished reshuffling into their new slots?
function CombatPanel:cardsSettled()
    return not self._cardsMoving
end

-- Is the strip finished with THIS body's arrival, and therefore ready to answer a hover about it?
--
-- `cardsSettled` alone cannot say, because of when it is asked: states/battle.lua builds the view in
-- refreshView, which runs BEFORE this panel's update on the same frame -- so on the very frame a turn
-- changes, `_cardsMoving` still holds last frame's answer, and last frame everything was at rest. The
-- gate passed, and the incoming actor's hover preview was painted the instant the hand-off began,
-- against a card that had not moved a pixel and figures that were still counting down.
--
-- IT HAS TO BE A LATCH, NOT A LIVE QUESTION, and asking it live is a feedback loop rather than a
-- near-miss. A preview is an extra ROW: showing it reflows the queue, which sets the cards moving,
-- which makes `cardsSettled` false, which withdraws the preview, which reflows the queue back, which
-- settles it, which shows the preview again. Measured with the pointer held still on the button: 33
-- appearances and disappearances in 241 frames, a clean fifteen-frame oscillation.
--
-- So the panel latches the fact once, the first time it comes to rest with this body in the frame,
-- and holds it until the next hand-off clears it. Motion the preview itself causes cannot revoke the
-- permission to draw the preview.
function CombatPanel:readyForPreview(unit)
    return unit ~= nil and self.arrivedCurrent == unit
end


-- Feed the per-frame render data (computed by the battle state). A new actor re-anchors the
-- turn strip to the bottom, so each turn opens showing whoever is acting now.
function CombatPanel:setView(view)
    view = view or { order = {}, items = {}, isPartyTurn = false }
    if view.current ~= self.view.current then self.scroll = 0 end
    self.view = view
end


-- Lay the panel out for a given width, and again whenever the logical space changes under it.
--
-- Split out of new() because the panel is CACHED on the battle state and the space is not fixed for
-- its lifetime any more: a handheld gets a shorter, narrower one (scale.lua), and a panel that laid
-- itself out once at construction would keep drawing for the shape it was born in. Everything here
-- derives from `w` and Scale.HEIGHT, so calling it again is the whole of what a space change needs.
--
-- The SLOT SIZE derives too. It used to be a module constant, which is fine while there is one panel
-- width in the game and wrong the moment there are two: a 3x3 grid of fixed 100px slots does not fit
-- a 262px column, and would have drawn straight out through the side of it.
function CombatPanel:relayout(w)
    w = w or PANEL_W
    self.x = Scale.WIDTH - w
    self.w = w

    -- Item grid: 3x3, centred horizontally, sized to the room there actually is. A long Wait button
    -- sits under it at the very bottom, so the grid is lifted to make way (button + gap + margin).
    -- The margin and the gap are the cheapest width there is: on a handheld they are framing the grid
    -- against a column that is already narrow, and every pixel of them comes straight off the slot,
    -- which is where the icon and its two badges have to live together. 10 and 6 bought a 66px slot
    -- in the narrowest space the game can produce, six short of the 72 two corner badges need -- and
    -- the slot is the only one of the three that has a hard floor under it. So on a handheld the
    -- framing yields first and the slot gets what it needs; see badgeStack below for what happens
    -- when even that is not enough.
    local margin = Scale.inHandheldSpace and 6 or SLOT_MARGIN
    self.slotGap = Scale.inHandheldSpace and 4 or SLOT_GAP
    self.slotW = math.min(SLOT_W, math.floor((w - margin * 2 - (COLS - 1) * self.slotGap) / COLS))
    self.slotH = SLOT_H
    self.gridW = COLS * self.slotW + (COLS - 1) * self.slotGap
    self.gridH = ROWS * self.slotH + (ROWS - 1) * self.slotGap
    self.gridX = self.x + math.floor((w - self.gridW) / 2)
    -- The bottom lane: one bar the width of the grid, pinned to the panel bottom. Wait/Focus/Defend
    -- owns the whole of it, and shares it with FALL BACK on the turns that move is on offer (see
    -- bottomBarRects). One lane, never two -- a second row reserved for a move that is legal on a
    -- handful of turns a fight is a permanent hole in the panel.
    self.waitBtn = self.waitBtn or {}
    self.waitBtn.x, self.waitBtn.w, self.waitBtn.h = self.gridX, self.gridW, 34
    self.waitBtn.y = Scale.HEIGHT - 16 - self.waitBtn.h
    self.waitHover = self.waitHover or false
    -- The item grid sits above the bottom lane. THIS LINE WENT OUT WITH FALL BACK and had
    -- nothing to do with it -- it sat between two of that button's fields, so the cut took it
    -- too, and every battle since has died constructing this panel (`arithmetic on field
    -- 'gridY' (a nil value)`). Nothing caught it: no spec builds a real panel, and the
    -- headless suite never opens one.
    self.gridY = self.waitBtn.y - 14 - self.gridH

    -- WHERE THE UPCOMING STRIP LIVES. Defaults to this panel, and a host may move it: on a handheld
    -- the right column is only 450 tall and cannot hold a strip, an acting card, a 3x3 grid and a Wait
    -- button at once, so states/battle.lua sends the strip to the left column and keeps the rest here.
    -- The acting card never moves -- it frames into the grid it belongs to.
    --
    -- These live HERE, not in new(), and that is not tidiness: they derive from `w` and from gridY,
    -- neither of which exists in new() any more. Left up there, self.stripW took a nil `w` and the
    -- panel's own "Turn Order" caption crashed on the desktop the moment it started reading it --
    -- while the handheld path went on working, because battle.syncLayout sets stripW explicitly.
    -- A SLOT'S COST AND INITIATIVE PILLS, sized to the slot they sit in.
    --
    -- The desktop numbers were chosen for a 96px slot carrying a name band as well. A handheld slot
    -- is 71px and has no band any more, so the same pill reads as two specks in a corner -- and a
    -- cost and a time cost are not decoration, they are the two numbers a turn is actually decided
    -- on. They get the room the name gave up.
    -- CORNERS IF THEY FIT, STACKED IF THEY DO NOT -- measured, not assumed. A slot's cost sits in
    -- its left corner and its initiative in its right one, which is the arrangement that leaves the
    -- icon between them entirely clear. It only works while two badges plus their corner pads fit
    -- across the slot; below that they were being drawn through each other, and stacking them down
    -- the left edge is the escape.
    --
    -- TWO PILLS, AND THE LARGER ONE FIRST. The handheld pill was a single size chosen for a 90px
    -- slot, and a 90px slot is not what every handset gives: on a narrow one the right column falls
    -- to 232 and the slot to 66, which is under the fat pill's corner fit AND under the lean one's --
    -- so the fat pill stacked, buried the icon under a badge top and bottom, and the only thing left
    -- of a Minor Shock was a sliver of lightning past the numbers. Measure both and take the first
    -- that keeps its corners; the lean pill fits a slot the fat one cannot, which is exactly what a
    -- fallback is for. Measured off a one-digit label with clearance to spare, since that is the
    -- common case and a rare two-digit cost may lean toward the middle without meeting anything.
    local function pill(padX, iconW, gap, h, font)
        return { padX = padX, iconW = iconW, gap = gap, h = h, font = font,
                 width = padX * 2 + iconW + gap + font:getWidth("9") }
    end
    local pills = {}
    if Scale.inHandheldSpace then
        -- The desktop numbers were chosen for a 96px slot carrying a name band as well. A handheld
        -- slot has no band any more, so the same pill reads as two specks in a corner -- and a cost
        -- and a time cost are not decoration, they are the two numbers a turn is actually decided
        -- on. They get the room the name gave up, when the slot has it to give.
        pills[#pills + 1] = pill(6, 13, 4, 25, Theme.body(17))
    end
    pills[#pills + 1] = pill(BADGE_PAD_X, BADGE_ICON_W, BADGE_GAP, BADGE_H, self.smallFont)
    local chosen, stack = pills[#pills], true
    for _, p in ipairs(pills) do
        if (p.width * 2 + 6 + 8) <= self.slotW then chosen, stack = p, false break end
    end
    self.badgePadX, self.badgeIconW, self.badgeGap, self.badgeH =
        chosen.padX, chosen.iconW, chosen.gap, chosen.h
    self.badgeFont = chosen.font
    self.badgeStack = stack
    -- THE GUTTER A STACK CLAIMS, and the width the icon has left because of it. Stacking runs a pill
    -- down the slot's left edge, top and bottom, so the icon must draw in what is left to the right
    -- of it rather than centred under it -- a smaller icon that can be seen beats a larger one behind
    -- two numbers. Zero in the corner arrangement, where the badges take the top corners only and the
    -- icon keeps the whole plate.
    self.badgeGutter = stack and (3 + chosen.width + 3) or 0

    self.stripX = self.x
    self.stripW = w
    self.stripFloor = nil -- set by a host that has sent the strip to another column
    -- stripTop leaves the caption clear breathing room above the first card.
    self.stripTop = 52
    -- Room between the acting card and the Actions grid below it -- enough for the centered "Actions"
    -- caption to breathe above and below without floating far from the grid.
    self.stripBottom = self.gridY - 32
end

function CombatPanel:contains(px, py)
    return px >= self.x and px <= self.x + self.w and py >= 0 and py <= Scale.HEIGHT
end

-- Item-grid slot rect for a 1-based index (row-major).
function CombatPanel:slotRect(index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    return self.gridX + col * (self.slotW + self.slotGap),
        self.gridY + row * (self.slotH + self.slotGap), self.slotW, self.slotH
end

-- The turn-order card `unit` currently occupies, as x, y, w, h -- or nil when it has no card on
-- screen (dead, or scrolled out of the strip). Reads the same entryLayout the strip draws from, and
-- honours the eased slot a sliding card is animating through, so a caller pointing at a card points
-- at where it actually IS mid-slide rather than where it will settle.
--
-- Exists for the tutorial's coaching bubble (states/battle.lua's `turn` anchor): a lesson about the
-- initiative timeline has to be able to point AT the timeline, and specifically at the one card that
-- just moved. Preview ghosts are skipped -- they are hypotheticals, not anybody's turn.
function CombatPanel:cardRect(unit)
    for _, e in ipairs(self:entryLayout()) do
        if not e.entry.preview and e.entry.unit == unit then
            return e.x, self.cardY[e.entry.unit] or e.y, e.w, e.h
        end
    end
    return nil
end

function CombatPanel:slotIndexAt(px, py)
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        if px >= sx and px <= sx + sw and py >= sy and py <= sy + sh then return i end
    end
    return nil
end

-- Why the current actor can't activate `item` right now (an unpayable cost, a spent stack, a
-- missing adjacent item), or nil when it can. Passive items report nil -- they're inert, not
-- blocked. Drives the grayed-out slot, its red badge and the refused click.
function CombatPanel:blockReason(item)
    return Combat.itemBlockReason(self.view.current, item)
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function CombatPanel:draw()
    -- Panel background. Softened (lower opacity, a dim 1px divider) so it frames the board
    -- without walling it in -- mirrors states/battle.lua drawLeftColumn.
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.x, 0, self.w, Scale.HEIGHT)
    -- The long panel/board seam is internal structure, not a framed edge -- a cool hairline, so it
    -- separates the two without a gold rule running the height of the screen.
    Theme.set(Theme.hairline)
    love.graphics.setLineWidth(1)
    love.graphics.line(self.x, 0, self.x, Scale.HEIGHT)

    love.graphics.setFont(self.headFont)
    -- Over the strip, wherever the strip is. It followed the cards to the left column on a handheld
    -- and this did not, which left a heading standing over an empty right column and a set of turn
    -- cards captioned by nothing.
    Theme.caption("Turn Order", self.stripX, self.stripTop - 32, self.stripW)

    self:drawTurnStrip()
    self:drawItemGrid()
    self:drawWaitButton()
    love.graphics.setColor(1, 1, 1)
end

-- The bottom lane: the Wait plate, holding all of it.
--
-- IT USED TO SPLIT. Fall Back sat beside Wait whenever the move was on offer -- the same KIND of move,
-- ending a turn without striking, so they read as one row -- and the lane halved to make room. Fall Back
-- is gone (models/combat.lua), and with nothing to share with, the split went too. Kept as a function
-- rather than folded into `self.waitBtn` at its two call sites, because "how is the lane divided" is a
-- question this panel should keep answering in one place if anything ever shares it again.
function CombatPanel:bottomBarRects()
    return self.waitBtn
end

-- The word the bottom lane's button wears for `unit`: whichever wait swap its kit grants, else plain
-- Wait. Static and pure so the plate and the note that explains it (waitNote, below) can never name
-- two different actions -- they are the same button, read twice.
function CombatPanel.waitLabel(unit)
    if not unit then return "Wait" end
    local behavior = Combat.waitBehavior(unit)
    local kind = behavior.kind
    -- A cycling stance names the air it would sound NEXT rather than the verb, because "Perform"
    -- alone would be a button that does a different thing every press with no way to see which.
    if kind == "perform" then
        local song = Combat.nextSong(unit, behavior)
        return (song and song.name) or "Perform"
    end
    return (kind == "focus" and "Focus") or (kind == "defend" and "Defend")
        or (kind == "overwatch" and "Overwatch") or (kind == "gather" and "Gather") or "Wait"
end

-- WHAT THAT BUTTON WILL DO, as a NoteTooltip title and paragraphs -- the hover reading on the one
-- control in the battle HUD that had none.
--
-- Every other plate in this panel is an item, and an item answers for itself (ui/item_tooltip.lua).
-- This one is chrome wearing a verb, and the verb is the least obvious action in the fight: a plain
-- Wait is not "skip", it is a re-entry just behind the next body, and a swapped one is a whole stance
-- whose numbers live on a piece of kit the player is not currently pointing at. The button said WHICH
-- and never WHAT.
--
-- TWO PARAGRAPHS, AND ONLY THE SECOND IS THIS FILE'S. The first is Combat.WAIT_SWAP_NOTE's -- the one
-- canonical sentence per stance, which the granting item's own tooltip prints word for word. A button
-- and an item describing one press in two different accounts is how the player learns to distrust
-- both, so the account is shared and the figures are all this adds.
--
-- The figures are read off the LIVE, level-resolved behavior, so a forged shield quotes the brace it
-- will actually plant. What they deliberately do NOT quote is the tempo: the timeline is already
-- painting this action's landing slot, with its figure, at the exact moment this box is up
-- (battle.hoverWait feeds the ghost), and a second answer in words would only be a chance to disagree.
function CombatPanel.waitNote(unit)
    local title = CombatPanel.waitLabel(unit)
    local behavior = unit and Combat.waitBehavior(unit) or { kind = "delay" }
    local kind = behavior.kind or "delay"

    -- The figures, as short clauses joined into one sentence rather than a paragraph each. A stance
    -- that hands out four things is a list, and four one-line paragraphs of "Every ally beside you..."
    -- is a wall where a list is wanted -- the shared sentence above has already said what the action
    -- IS, and this only has to say how much.
    local clauses = {}
    local function add(text) if text then clauses[#clauses + 1] = text end end
    -- Names for the things a named stance hands out. A status or hazard id nobody authored a def for
    -- is skipped rather than printed raw: an id in prose reads as a bug, and the clause it would sit
    -- in is an extra, not the sentence the button is being asked for.
    local function statusName(id)
        local def = id and Status.defs[id]
        return def and def.name
    end
    -- A figure only when there IS one. An instantiated item has had its curves resolved to numbers at
    -- its forge level (models/item.lua), but a behavior read off anything less than a live instance
    -- still carries the Curve table, and `tostring` on one prints an address into the player's prose.
    -- A clause without its number is dropped rather than printed blank; the shared sentence stands.
    local function num(v) return type(v) == "number" and tostring(v) or nil end
    local function fmt(pattern, v) local n = num(v); return n and string.format(pattern, n) or nil end

    if kind == "defend" then
        add(fmt("braces +%s", behavior.defense))
        add(fmt("every ally beside you +%s", behavior.covers))
        add(statusName(behavior.status) and ("also grants " .. statusName(behavior.status)))
        add(statusName(behavior.coversStatus)
            and ("allies beside you gain " .. statusName(behavior.coversStatus)))

    elseif kind == "focus" then
        add(fmt("restores %s mana", behavior.mana))
        add(fmt("every ally beside you +%s mana", behavior.covers))
        add(statusName(behavior.status) and ("also grants " .. statusName(behavior.status)))
        add(statusName(behavior.afflicts)
            and ("enemies beside you take " .. statusName(behavior.afflicts)))
        local hazard = behavior.hazard and Hazard.defs[behavior.hazard.id]
        if hazard and hazard.name then
            add("lays " .. hazard.name .. ((behavior.hazard.radius or 0) > 0
                and " over the ground around you" or " on the tile you stand on"))
        end
        -- The toll is the one clause here that is a COST, and it is the one a player most needs before
        -- pressing: an overchannelled staff buys its deeper mana out of the meditating body. Last, so
        -- the sentence ends on what it takes.
        if behavior.toll and behavior.toll.stat then
            add(fmt("costs you %s " .. behavior.toll.stat, behavior.toll.amount))
        end

    elseif kind == "overwatch" then
        add(fmt("each shot spends %s stamina", behavior.stamina))
        add(fmt("ground beside you costs an enemy %s more to step onto", behavior.zone))
        add("lapses when your own next turn opens")

    elseif kind == "gather" then
        add(fmt("stores +%s attack", behavior.power))
        add(fmt("every ally beside you +%s", behavior.covers))

    elseif kind == "perform" then
        local song, idx = Combat.nextSong(unit, behavior)
        add(statusName(song and song.status) and ("lands " .. statusName(song.status)))
        add(fmt("within %s tiles", behavior.earshot))
        add(fmt("holds %s turns", behavior.duration))
        -- The ORDER is what this stance costs (models/combat.lua's Combat.perform), so the clause list
        -- ends by pointing on. The button can only ever name one air; the decision is which one you are
        -- spending turns to reach.
        local songs = behavior.songs or {}
        if #songs > 1 then
            local nxt = songs[(idx % #songs) + 1]
            add(nxt and nxt.name and ("next air: " .. nxt.name))
        end
    end

    local lines = { Combat.WAIT_SWAP_NOTE[kind] or Combat.WAIT_SWAP_NOTE.delay }
    if #clauses > 0 then
        -- Joined, then raised at the front: which clause leads depends on what this particular piece of
        -- kit declares (a shield naming no `defense` opens on its covers instead), so the capital cannot
        -- be authored into any one of them.
        local text = table.concat(clauses, "; ") .. "."
        lines[#lines + 1] = text:sub(1, 1):upper() .. text:sub(2)
    end
    return title, lines
end

-- The long Wait button under the item grid. Its label mirrors the acting unit's wait behavior
-- (item-swapped Focus / Defend, else Wait), matching the old corner button. Enabled only on a party
-- turn; brightens under the cursor (waitHover) or while the keyboard Wait preview is armed
-- (view.waitPreview). The battle state supplies onWait and reads waitHover (set in mousemoved) to
-- preview the delay slot on the timeline -- and to raise waitNote's reading over it.
function CombatPanel:drawWaitButton()
    local b = self:bottomBarRects() -- half the lane on the turns Fall Back shares it
    local enabled = self.view.isPartyTurn
    -- Brightens under the mouse (waitHover) OR while the keyboard Wait preview is armed (view.waitPreview,
    -- the first of its two presses) -- both are the selection resting on Wait, so it lights the same way.
    local hot = enabled and (self.waitHover or self.view.waitPreview)
    local label = CombatPanel.waitLabel(self.view.current)
    if enabled then Theme.set(hot and Theme.panel or Theme.panel2)
    else Theme.set(Theme.slot) end
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6, 6)
    -- Selected/hovered reads with the same weight an armed action slot does: a bright amber trim
    -- at 2px, not just a quieter-vs-brighter fill. A keyboard/pad player crossing onto Wait has no
    -- mouse cursor pointing at it, so the plate itself has to announce the selection loudly.
    if hot then Theme.set(Theme.accentAmber) else Theme.set(Theme.frame, enabled and 1 or 0.5) end
    love.graphics.setLineWidth(hot and 2 or 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6, 6)
    love.graphics.setLineWidth(1)
    if not enabled then Theme.set(Theme.muted)
    elseif hot then Theme.set(Theme.accentAmber)
    else Theme.set(Theme.ink) end
    love.graphics.setFont(self.nameFont)
    -- UPPERCASE and letter-tracked, matching the section captions -- this button is a chrome header,
    -- not prose. A performer's label is a song title rather than a verb, so it is trimmed to the plate:
    -- half a lane is narrow, and the tracking is part of what has to fit.
    label = string.upper(label)
    label = Theme.ellipsize(label, self.nameFont, b.w - 16 - #label * Theme.TRACK)
    Theme.printTracked(label, b.x, b.y + b.h / 2 - 9, b.w)
end

-- Is (px, py) over the Wait button? Asks the same split the plate was drawn from, so the half Fall
-- Back is standing in never answers for Wait.
function CombatPanel:overWait(px, py)
    local b = self:bottomBarRects()
    return px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h
end

-- Is the acting card pinned at the bottom right now? It is whenever the current unit heads the
-- order (refreshView anchors its real entry at index 1). When there's no current -- battle over,
-- a lull -- nothing is pinned and every entry scrolls as a uniform slim card.
-- The entry list the strip lays out from. Kept as its own call because several measurements ask for
-- it and they must all ask the same question.
function CombatPanel:orderList()
    return self.view.order or {}
end

function CombatPanel:hasPinnedCurrent()
    local first = self:orderList()[1]
    return self.view.current ~= nil and first ~= nil and not first.preview
        and first.unit == self.view.current
end

-- Top of the pinned acting card. A fixed rect, not a search through the layout: the caption hangs off
-- it, the action grid frames into it, and during a frozen hand-off the layout's first entry is the
-- outgoing unit rather than the current one.
function CombatPanel:pinnedTop()
    return self.stripBottom - CURRENT_H
end

-- Bottom edge of the scrollable (upcoming) region: just above the pinned current card (leaving its
-- caption gap), or the strip bottom when nothing is pinned. The current card is fixed here.
--
-- A strip sent to another column stacks in ITS band instead (stripFloor), exactly as entryLayout
-- lays it out -- and this must say the same thing entryLayout does, because visibleCount and
-- maxScroll are measured off it. Left reading the panel's own geometry it answered for a region the
-- cards are not in: on a handset the acting card's reserved slot sits ABOVE stripTop, so the span
-- came out negative, one card was reckoned to fit where three do, and the strip showed a scrollbar
-- and scrolled a queue that was entirely on screen.
function CombatPanel:upcomingBottom()
    if self.stripFloor then return self.stripFloor end
    if self:hasPinnedCurrent() then
        return self.stripBottom - CURRENT_H - CURRENT_TOP_GAP
    end
    return self.stripBottom
end

-- Stack the upcoming (slim) cards upward from the region's floor, starting `scroll` entries along,
-- and return the ones that FIT WHOLE -- a card that would cross stripTop is dropped, never drawn cut
-- off. Kept as one function rather than folded back into arithmetic now that the pitch is uniform
-- again, because it is the single place the stacking geometry lives: entryLayout draws what this
-- returns, visibleCount counts it and maxScroll walks it. Three answers from one walk cannot disagree
-- with each other; three copies of a formula can.
function CombatPanel:stackUpcoming(entries, startIndex, scroll)
    local out = {}
    local y = self:upcomingBottom()
    local skipped = 0
    for i = startIndex, #entries do
        skipped = skipped + 1
        if skipped > scroll then
            local top = y - SLIM_H
            if top < self.stripTop then break end
            out[#out + 1] = { entry = entries[i], index = i, y = top }
            y = top - ENTRY_GAP
        end
    end
    return out
end

-- How many upcoming cards are actually on screen, and how far the region can scroll before the last
-- of them sits at the bottom. Both answer off stackUpcoming rather than off a card height, so they
-- say whatever the strip is actually drawing.
function CombatPanel:visibleCount()
    local entries = self:orderList()
    local startIndex = self:hasPinnedCurrent() and 2 or 1
    return math.max(1, #self:stackUpcoming(entries, startIndex, self.scroll))
end

function CombatPanel:maxScroll()
    local entries = self:orderList()
    local startIndex = self:hasPinnedCurrent() and 2 or 1
    local total = #entries - startIndex + 1
    if total <= 0 then return 0 end
    for s = 0, total - 1 do
        if s + #self:stackUpcoming(entries, startIndex, s) >= total then return s end
    end
    return total - 1
end

-- The on-screen rect of each visible turn-strip entry, shared by draw + hover hit-testing.
-- Each entry carries its turn-order number (`num`): 1 = acting now, matching the board token
-- (ui/battle_map.lua) so the player can tie a strip row to a unit at a glance. Preview ghosts
-- don't consume a number (they're a hypothetical slot, not a live position), so the numbers
-- stay aligned with the board's live turn order.
--
-- Only the `scroll`..`scroll + visibleCount` window is laid out, but numbering walks the whole
-- order so a scrolled-to entry keeps the #N its board token shows.
function CombatPanel:entryLayout()
    local out = {}
    local entries = self:orderList()
    -- The order shrinks as units die and grows with summons/preview ghosts, so re-clamp here
    -- rather than trusting the offset left by the last scroll input.
    self.scroll = math.max(0, math.min(self.scroll, self:maxScroll()))
    local turnNo = 0
    local startIndex = 1
    -- The acting card is PINNED at the bottom (just above the item grid it frames into), reserving
    -- CURRENT_H there regardless of scroll -- it never scrolls away. It's anchored at index 1 by the
    -- battle state's timeline build. Everything else stacks above it as the scrollable region.
    if self:hasPinnedCurrent() then
        turnNo = 1
        out[#out + 1] = { entry = entries[1], num = 1, x = self.x + 8, y = self:pinnedTop(),
                          w = self.w - 16, h = CURRENT_H }
        startIndex = 2
    end
    -- Numbering walks EVERY entry, scrolled off or not, so a scrolled-to card keeps the #N its board
    -- token shows. A preview slot consumes no number: a ghost is a hypothetical and a repeat is a
    -- projection, and neither is anybody's turn.
    local num = {}
    for i = startIndex, #entries do
        if not entries[i].preview then
            turnNo = turnNo + 1
            num[i] = turnNo
        end
    end
    -- The upcoming cards themselves, spaced by the wait between them (stackUpcoming). A strip sent to
    -- another column stacks in ITS band, which is why the x/w below come from stripX/stripW and the
    -- acting card's above come from the panel's own -- the acting card never leaves the panel.
    for _, row in ipairs(self:stackUpcoming(entries, startIndex, self.scroll)) do
        -- `index` travels with the row: it is the entry's place in the order, and drawOffTopPreview
        -- needs it to tell a slot that fell off the TOP from one merely scrolled out of view below.
        out[#out + 1] = { entry = row.entry, num = num[row.index], index = row.index,
                          x = self.stripX + 8, y = row.y, w = self.stripW - 16, h = SLIM_H }
    end
    return out
end

function CombatPanel:drawTurnStrip()
    self.poolCallouts:clear() -- refilled by drawPoolBars below, then floated over the cards at the end
    local layout = self:entryLayout()
    -- THE CARD IN MOTION IS DRAWN LAST, over the ones it is passing. A card travelling from the frame
    -- to the rank its cost bought has to cross every rank between the two -- that is what travelling
    -- IS, and it is the price of being able to follow it at all. What is NOT acceptable is the pair
    -- interpenetrating: two plates at the same depth, two names printed through each other, and the
    -- card you were following the harder of the two to see. Drawn on top it simply passes in front,
    -- which is what a moving object does, and it stays wholly legible the whole way.
    -- DEPTH SAYS WHICH ROW MATTERS. Every row on this strip is easing toward a slot of its own, and
    -- when the order changes they cross -- that is what movement is, and the price of being able to
    -- follow anything at all. What must never happen is two rows meeting AT THE SAME DEPTH, printing
    -- through each other so that the one you were watching is the harder of the two to read. So they
    -- are drawn in three passes, back to front:
    --
    --   1. hypotheticals -- ghosts and repeat slots. A projection may be crossed by a body; it may
    --      never obscure one.
    --   2. the live cards.
    --   3. whichever card is in FLIGHT out of the frame, over everything, because it is the one the
    --      player is most likely to be following.
    local lift = (self.phase == "out") and self.outgoingUnit or nil
    local lifted
    local function rowY(e)
        if not e.entry.preview and self.cardY[e.entry.unit] then
            return self.cardY[e.entry.unit] -- eased slot (slides as the order reshuffles)
        elseif e.entry.preview and e.entry.ghostSlot then
            local slots = self.ghostY[e.entry.unit]
            return (slots and slots[e.entry.ghostSlot]) or e.y -- ...and a hypothetical slides with them
        end
        return e.y
    end
    for pass = 1, 2 do
    for _, e in ipairs(layout) do
        local y = rowY(e)
        if (e.entry.preview and pass ~= 1) or (not e.entry.preview and pass ~= 2) then
            -- drawn in the other pass
        elseif lift and not e.entry.preview and e.entry.unit == lift then
            lifted = { e = e, y = y }
        else
        -- A card drawn where entryLayout put it, which for the upcoming strip may be another column
        -- entirely (see relayout's stripX). drawEntry lays every part of a card out from self.x, so
        -- rather than thread a rect through all of it, the whole card is TRANSLATED into place.
        --
        -- THE WIDTH HAS TO GO WITH IT. This used to translate and nothing else, on the grounds that
        -- "the two columns are the same width by construction" -- which stopped being true the day
        -- battle.syncLayout stopped splitting the leftover evenly: the right column now asks for what
        -- the item grid needs and the left takes the rest, so on a narrow handset they are 232 and
        -- 200. A card translated but still drawn `self.w - 16` wide hung 24px of every upcoming turn
        -- out over the board. entryLayout already measures each card against the column it is going
        -- to, so the fix is to draw the width it worked out rather than the panel's own.
        local shift = e.x - (self.x + 8)
        if shift ~= 0 then love.graphics.push(); love.graphics.translate(shift, 0) end
        self:drawCard(e.entry, y, e.num, e.h, nil, e.w)
        if shift ~= 0 then love.graphics.pop() end
        end
    end
    end
    if lifted then
        local e = lifted.e
        local shift = e.x - (self.x + 8)
        if shift ~= 0 then love.graphics.push(); love.graphics.translate(shift, 0) end
        self:drawCard(e.entry, lifted.y, e.num, e.h, nil, e.w)
        if shift ~= 0 then love.graphics.pop() end
    end
    -- A just-fallen unit's card, fading to black in place before it's gone (it has already left the
    -- live order, so it isn't in entryLayout above). Drawn at the width and in the column it last
    -- occupied, for the same reason the live cards above are.
    for u, dc in pairs(self.dyingCards) do
        local fade = (self.fx and self.fx:deathFade(u)) or 0
        local shift = (dc.x or (self.x + 8)) - (self.x + 8)
        if shift ~= 0 then love.graphics.push(); love.graphics.translate(shift, 0) end
        self:drawCard(dc.entry, dc.y, nil, dc.h, nil, dc.w)
        love.graphics.setColor(0, 0, 0, fade)
        love.graphics.rectangle("fill", self.x + 8, dc.y, dc.w or (self.w - 16), dc.h, 6, 6)
        if shift ~= 0 then love.graphics.pop() end
    end
    self:drawOffTopPreview(layout)
    -- THE CAPTION GOES OVER THE CARDS, not behind them, and that is what lets the arriving actor
    -- travel. It eases down from its old rank and its route crosses this line; drawn underneath, the
    -- card swallowed the words for the length of the trip. The first fix was to stop the card
    -- travelling at all -- which cured the overlap by making the arrival something nobody could watch.
    -- Drawn over the top instead, the card passes BEHIND the caption and stays in sight the whole way,
    -- and at rest the two do not overlap by a pixel (the caption sits 24 above the frame), so this
    -- costs nothing on every frame that is not a hand-off.
    self:drawActivePanel()
    self:drawScrollBar()
    -- Last, so a projection floats clear over the card it belongs to. Clamped to the panel's inner
    -- edges so a pill on a nearly-full bar can't hang off into the board.
    self.poolCallouts:draw(self.x + 10, self.x + self.w - 10)
end

-- Draw one turn-strip card at (its left is self.x + 8) row-top `y`, applying the struck unit's hit
-- rumble (a translated shake) and flash (a red overlay) so a blow reads on the timeline card exactly
-- as it does on the board sprite. Preview ghosts and un-struck cards just draw plainly.
--
-- `w` is the card's own width, for a strip that has been sent to a column narrower than this panel
-- (see drawTurnStrip); it defaults to the panel's own inner width, which is what the acting card and
-- every desktop card wants.
function CombatPanel:drawCard(entry, y, num, h, alpha, w)
    w = w or (self.w - 16)
    local u = not entry.preview and entry.unit
    local dx, dy, flash = 0, 0, 0
    if u and self.fx then
        dx, dy = self.fx:cardShake(u)
        flash = self.fx:cardFlash(u)
    end
    if dx ~= 0 or dy ~= 0 then
        love.graphics.push()
        love.graphics.translate(dx, dy)
    end
    self:drawEntry(entry, y, num, h, alpha, w)
    if flash > 0 then
        love.graphics.setColor(1.0, 0.4, 0.35, flash * 0.45)
        love.graphics.rectangle("fill", self.x + 8, y, w, h, 6, 6)
    end
    -- Hovering a combat-log line lights the units it names -- here on the strip and, in the same
    -- white, on the board (ui/battle_map's logSubjects). So a line about a unit that has already
    -- scrolled off the board's centre of attention is still findable: look for the white. Drawn over
    -- the finished card, and never on a preview ghost -- a hypothetical slot is nobody's turn.
    local hl = self.view.logHighlight
    if u and hl and hl[u] then
        local pulse = 0.55 + 0.45 * math.sin((self.time or 0) * 5)
        love.graphics.setColor(1, 1, 1, 0.07)
        love.graphics.rectangle("fill", self.x + 8, y, w, h, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.50 + 0.40 * pulse)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x + 8, y, w, h, 6, 6)
        love.graphics.setLineWidth(1)
    elseif u and u == self.view.boardHover then
        -- Pointing at a body on the board rings ITS card here, in the exact cyan the board rings a
        -- card-hovered body with (ui/battle_map's drawHighlights): one colour, meaning "this is the
        -- one you are pointing at", answered on whichever surface the cursor is NOT on. Steady, not
        -- pulsing -- it tracks the cursor rather than answering a question, which is what the log's
        -- white pulse is for, and why that one wins the card when both apply.
        love.graphics.setColor(0.75, 0.95, 1.0, 0.08)
        love.graphics.rectangle("fill", self.x + 8, y, w, h, 6, 6)
        love.graphics.setColor(0.75, 0.95, 1.0, 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x + 8, y, w, h, 6, 6)
        love.graphics.setLineWidth(1)
    end
    if dx ~= 0 or dy ~= 0 then love.graphics.pop() end
end

-- The "Current Turn" section caption above the acting card. NO enclosing box: the mock lets the
-- current card, the Actions grid and the Wait button sit as separate bordered elements in the panel's
-- negative space, not wrapped in one module. Each carries its own frame -- the card its bone-gold
-- border + carved corners (drawEntry), the grid its slots, the Wait button its plate -- so the section
-- reads by its caption and the breathing room around it, not by a bracket.
function CombatPanel:drawActivePanel()
    -- Off the pinned rect, not off a search for the current unit: during a frozen hand-off the
    -- layout's first entry is the OUTGOING body, and a search would drop the caption for the whole
    -- phase -- it blinked out and back on every single turn.
    if not self:hasPinnedCurrent() then return end
    love.graphics.setFont(self.captionFont)
    Theme.caption("Current Turn", self.x + 5, self:pinnedTop() - 24, self.w - 10)
end

-- A thin track + thumb down the strip's right edge, drawn only when the order overflows. It is
-- the affordance that says "there are later turns up there" and shows where the window sits.
function CombatPanel:drawScrollBar()
    local max = self:maxScroll()
    if max == 0 then return end
    -- The track spans only the scrollable region (above the pinned current card), since that card
    -- never moves -- so the bar sits over exactly what it scrolls.
    local total = #(self:orderList()) - (self:hasPinnedCurrent() and 1 or 0)
    -- Down the STRIP's right edge, wherever the strip is -- not the panel's. It followed the cards
    -- to the left column on a handheld and this did not, which put the track over the board.
    local bx, bw = self.stripX + self.stripW - 5, 3
    local by, bh = self.stripTop, self:upcomingBottom() - self.stripTop

    Theme.set(Theme.frame, 0.25)
    love.graphics.rectangle("fill", bx, by, bw, bh, 2, 2)

    -- The window covers visibleCount/total of the upcoming entries; scroll 0 pins the thumb to the
    -- bottom, because the strip counts upward from "now".
    local thumbH = math.max(24, bh * (self:visibleCount() / total))
    local t = self.scroll / max
    Theme.set(Theme.frame, 0.7)
    love.graphics.rectangle("fill", bx, by + (1 - t) * (bh - thumbH), bw, thumbH, 2, 2)
end

-- A SLOT THAT LANDS ABOVE THE STRIP still has to be announced. A preview is the answer to "where does
-- this put me", and a queue longer than the panel can show swallows that answer whole: the player
-- aims, the ghost is laid out past the top card, nothing is drawn, and the strip says the action has
-- no effect on the order at all. So the top of the band carries a mark instead -- an upward chevron
-- and the wait itself, in the slot's own faction colour and under a dashed rule, which is the same
-- vocabulary the ghost card would have used had there been room for it.
--
-- Counts only hypotheticals that were laid out ABOVE the last drawn row. A ghost hidden by SCROLLING
-- is a different thing -- the scrollbar already says there is more up there, and the player put it
-- out of view themselves.
function CombatPanel:drawOffTopPreview(layout)
    local drawn, last = {}, 0
    for _, e in ipairs(layout) do
        drawn[e.entry] = true
        if e.index and e.index > last then last = e.index end
    end
    local entries = self:orderList()
    local best
    for i = 1, #entries do
        local entry = entries[i]
        if entry.preview and not drawn[entry] and i > last then
            if not best or (entry.initiative or 0) < (best.initiative or 0) then best = entry end
        end
    end
    if not best then return end

    local fc = self:unitColor(best.unit)
    local y = self.stripTop - 13
    local cx = self.stripX + self.stripW / 2
    love.graphics.setFont(self.smallFont)
    local text = string.format("%.1f", self:shownWait(best.initiative))
    local tw = self.smallFont:getWidth(text)
    local iconW, gap, chev = 7, 3, 9
    local total = chev + 4 + iconW + gap + tw
    local x = cx - total / 2

    -- the chevron: two strokes, pointing up the way the slot lies
    love.graphics.setColor(fc[1], fc[2], fc[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y + 8, x + chev / 2, y + 2)
    love.graphics.line(x + chev / 2, y + 2, x + chev, y + 8)
    love.graphics.setLineWidth(1)

    local ia = Theme.accentAmber
    self:drawHourglass(x + chev + 4, y + 1, iconW, 9, ia[1], ia[2], ia[3], 0.95)
    love.graphics.setColor(ia[1], ia[2], ia[3], 0.95)
    love.graphics.print(text, x + chev + 4 + iconW + gap, y - 1)

    -- and the dash under it, which is what says "hypothetical" everywhere else on this strip
    Theme.set(fc, 0.55)
    local dash, xx = 5, x - 2
    while xx < x + total + 2 do
        love.graphics.line(xx, y + 12, math.min(xx + 3, x + total + 2), y + 12)
        xx = xx + dash
    end
end

-- A dashed rectangle border, used to mark preview (ghost) entries as hypothetical and to dissolve
-- out as a just-committed ghost solidifies into its real card (`alpha` fades it). The DASH says
-- "hypothetical"; the `color` (defaulting to the trim gold) says whose slot it is -- ghost cards
-- pass their unit's faction colour, since they carry no HP bar to say it for them.
function CombatPanel:dashedRect(x, y, w, h, alpha, color)
    Theme.set(color or Theme.accentAmber, alpha or 0.9)
    love.graphics.setLineWidth(1)
    local dash, gap = 6, 4
    local xx = x
    while xx < x + w do
        local seg = math.min(dash, x + w - xx)
        love.graphics.line(xx, y, xx + seg, y)
        love.graphics.line(xx, y + h, xx + seg, y + h)
        xx = xx + dash + gap
    end
    local yy = y
    while yy < y + h do
        local seg = math.min(dash, y + h - yy)
        love.graphics.line(x, yy, x, yy + seg)
        love.graphics.line(x + w, yy, x + w, yy + seg)
        yy = yy + dash + gap
    end
end

-- Rects of the active status badges on `unit`'s turn-strip entry (entry left/width ex/ew, row
-- top ey). Shared by drawEntry + statusAt so a badge's tooltip lands exactly where it's drawn.
-- Anchored right and laid out right-to-left, leaving room at the far edge for the initiative num.
function CombatPanel:statusBadgeRects(unit, ex, ew, ey)
    local statuses = unit.statuses
    if not statuses or #statuses == 0 then return {} end
    local bw, bh, gap = 18, 14, 3
    local out = {}
    local x = ex + ew - 40
    for i = #statuses, 1, -1 do
        x = x - bw
        out[#out + 1] = { st = statuses[i], x = x, y = ey + 4, w = bw, h = bh }
        x = x - gap
    end
    return out
end

-- The portrait square (sprite, or a coloured letter box as a fallback) at (px, py), size ps.
function CombatPanel:drawPortrait(unit, px, py, ps, a)
    local sprite = unit.char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, a)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        local c = self:unitColor(unit)
        love.graphics.setColor(c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, a)
        love.graphics.rectangle("fill", px, py, ps, ps, 4, 4)
        local big = ps >= 48
        love.graphics.setFont(big and self.headFont or self.smallFont)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.printf((unit.char.name or "?"):sub(1, 1), px, py + ps / 2 - (big and 10 or 7), ps, "center")
    end
end

-- Turn-order number in the card's left gutter -- deliberately clear of the portrait so it never
-- hides the face -- vertically centred, larger and gold on the acting card. #1 = acting now, matching
-- the board token (ui/battle_map.lua drawTurnNumber) so the same #N points at the same unit on both.
function CombatPanel:drawTurnNumber(num, cardX, cardTop, cardH, p)
    if not num then return end
    local font = (p > 0.5) and self.headFont or self.nameFont
    love.graphics.setFont(font)
    if p > 0.5 then Theme.set(Theme.accentAmber, lerp(0.9, 1, p)) else Theme.set(Theme.ink, 0.9) end
    love.graphics.printf(tostring(num), cardX + 1, cardTop + cardH / 2 - font:getHeight() / 2, NUM_GUTTER - 2, "center")
end

-- THE WAIT: how long until this body acts (0 = acting now), including a projected slot's figure.
-- Tagged with an hourglass -- the same time-to-act glyph as the speed badge, and the same mark every
-- duration in the game wears -- so it reads as a timer rather than as a stat.
--
-- IT IS THE INSTRUMENT, NOT A DEBUG READ-OUT, and after the strip stopped spacing its cards by the
-- wait it is the ONLY one: an evenly pitched queue says who is next and nothing whatever about how
-- long until they move, so every bit of that reading is carried here. The framing is what changed,
-- not the drawing -- it was written as a developer's aid and shipped switched on anyway
-- (states/battle.lua sets showInitiative at every battle open), and F6 is the toggle for turning the
-- instrument off rather than the one that grudgingly turns it on.
--
-- IT WAS BRIEFLY DRESSED UP, on a tinted ground with a gold edge and a size of its own, on the
-- argument that a number meant to be READ should not look like the grey values around it. Reverted
-- with the spacing it was pitched beside: the plain amber figure reads perfectly well and the plate
-- was chrome the card did not need.
-- `shownClock` is what makes the figure agree with the preview that promised it: see the note on the
-- field. While the strip's clock trails the model's, every card reads the wait the ghost quoted, and
-- the catch-up is the count-down the player watches.
-- The figure's own rect: glyph, gap and digits, as one hoverable thing. Shared by the draw and by
-- initiativeAt, the way statusBadgeRects is, so the tooltip lands exactly on what is drawn rather
-- than on a second guess at where it went.
function CombatPanel:initiativeRect(entry, ex, ew, ey)
    if not (self.view.showInitiative and entry and entry.initiative) then return nil end
    local text = string.format("%.1f", self:shownWait(entry.initiative))
    local tw = self.smallFont:getWidth(text)
    local iconW, gap = 7, 3
    local w = iconW + gap + tw
    -- A couple of pixels of slack all round: the glyph is 7px wide and the digits are 12pt, and a
    -- target that small wants a little more than its own ink to be hoverable with a real hand.
    return ex + ew - 6 - w - 2, ey + 1, w + 8, 15, iconW, gap, tw
end

function CombatPanel:drawInitiative(entry, ex, ew, ey, tempo)
    if not (self.view.showInitiative and entry.initiative) then return end
    love.graphics.setFont(self.smallFont)
    local text = string.format("%.1f", self:shownWait(entry.initiative))
    local tw = self.smallFont:getWidth(text)
    local iconW, gap = 7, 3
    local ia = Theme.accentAmber
    -- A wait that just MOVED without the order moving reports which way it went, for as long as the
    -- pulse runs, and it does it in the FIGURE rather than in any chrome around it: the queue is
    -- evenly pitched, so a change that reorders nobody leaves every card exactly where it stands and
    -- this is the only thing on the strip that can say so (see trackTempo). Sooner lifts the gold
    -- toward white and falls back to it; later dips the whole read-out and climbs back.
    local r, g, b, a = ia[1], ia[2], ia[3], 0.95
    if tempo then
        local f = tempo.t / TEMPO_PULSE
        if tempo.dir == "sooner" then
            r, g, b = lerp(r, 1, f), lerp(g, 1, f), lerp(b, 1, f)
            a = 1
        else
            a = 0.50 + 0.45 * (1 - f)
        end
    end
    -- Laid out from the same rect the hover tests against, so the two cannot drift apart.
    local rx = self:initiativeRect(entry, ex, ew, ey)
    self:drawHourglass(rx + 2, ey + 4, iconW, 9, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.printf(text, ex, ey + 3, ew - 6, "right")
end

-- The acting unit's full pool stack (HP/MP/SP, each max>0), stacked from topY: a colour-tinted
-- HP/MP/SP tag, the bar, and the value ("cur / max") in a shared right-hand column so the three rows
-- align. This detail is the current card's alone -- slim cards show just a thin HP bar -- so the
-- numbers only appear where an action budget is being read. What an aimed action would leave behind
-- is quoted separately, by the floating callouts (ui/pool_callout.lua).
function CombatPanel:drawPoolBars(unit, rx, rw, topY, alpha, pitch)
    alpha = alpha or 1
    pitch = pitch or POOL_PITCH
    local pv = self.view.preview and self.view.preview[unit]
    local rows = {}
    for _, res in ipairs(RESOURCES) do
        local stat = unit.char.stats[res.key]
        if type(stat) == "table" and (stat.max or 0) > 0 then
            -- Damage/heal lands on HP; a cast's cost and a summon's reservation both come out of
            -- `current` (Combat.abilitySpend), so accumulate every spend row for this pool.
            local delta, lethal = 0, false
            if pv then
                if res.key == "health" then delta = (pv.heal or 0) - (pv.damage or 0); lethal = pv.lethal end
                for _, s in ipairs(pv.spend or {}) do
                    if s.stat == res.key then delta = delta - (s.amount or 0) end
                end
            end
            -- Draw against the EFFECTIVE ceiling (base max plus any carried resource-passive):
            -- unreservedMax folds in char.maxBonus; adding the reserved amount back recovers the full max.
            local reserved = Combat.reservedAmount(unit.char, res.key)
            local effMax = Combat.unreservedMax(unit.char, res.key) + reserved
            -- The value column stays "cur / max" no matter what is aimed: the projection is quoted by
            -- the floating callout instead, so the numbers under the cursor hold still.
            local curN, maxN = math.floor(stat.current + 0.5), math.floor(effMax + 0.5)
            local text = curN .. " / " .. maxN
            -- The HP bar fill drains from the lagging shown value; the numeric label stays the true
            -- current so it reads the real number the instant a hit lands.
            local barCur = res.key == "health" and self:shownHealth(unit) or stat.current
            rows[#rows + 1] = { res = res, cur = barCur, trueCur = stat.current, effMax = effMax,
                delta = delta, lethal = lethal, reserved = reserved, text = text }
        end
    end

    -- Each row is marked with its pool's glyph (heart / gem / drop) just after the HP/MP/SP tag, the
    -- same shape the cost badges price a cast in -- so a spend badge and the bar it drains from carry
    -- one mark between them. Both are tinted alike, and the label stays: the letters open the row,
    -- the glyph closes it against the bar it fills. It sits in a fixed column, not tight against the
    -- text, so the three marks line up with each other down the stack.
    local barH, glyphW, glyphGap, labelW = 9, 7, 5, 22
    love.graphics.setFont(self.smallFont)
    local valueColW = 2
    for _, r in ipairs(rows) do valueColW = math.max(valueColW, self.smallFont:getWidth(r.text) + 2) end
    for i, r in ipairs(rows) do
        local rowY = topY + (i - 1) * pitch
        local c = self:barColor(r.res, unit)
        -- The tag/glyph tint: the bar's colour lifted toward white so it stays legible at 9px on the
        -- dark card.
        local tr, tg, tb = c[1] * 0.6 + 0.28, c[2] * 0.6 + 0.28, c[3] * 0.6 + 0.28
        love.graphics.setColor(tr, tg, tb, 0.95 * alpha)
        love.graphics.print(BAR_LABELS[r.res.key], rx, rowY + (barH - self.smallFont:getHeight()) / 2)
        local glyph = Glyphs.RESOURCE[r.res.key]
        if glyph then glyph(rx + labelW, rowY, glyphW, barH, tr, tg, tb, 0.95 * alpha) end
        local barX = rx + labelW + glyphW + glyphGap
        local barW = rw - (barX - rx) - valueColW - 6
        -- The HEALTH row alone carries a boss's phase notches; mana and stamina have no stages to mark.
        drawResourceBar(barX, rowY, barW, barH, r.cur, r.effMax, c, r.delta, r.lethal, r.reserved, alpha,
            r.res.key == "health" and Combat.isBoss(self.combat, unit) and Combat.bossThresholds(unit) or nil)
        -- Queue this row's projection for the floating pass. Anchored at the level the bar will
        -- SETTLE at (the after ratio), which is exactly the edge the pending slice ends on, so the
        -- pill points at the line the fill is about to move to.
        if r.delta ~= 0 and r.effMax > 0 and alpha > 0.5 then
            local afterRatio = math.max(0, math.min(1, (r.cur + r.delta) / r.effMax))
            -- The pill quotes the pool's NEW value, not the size of the change: what a player decides
            -- on is what they will be left with. The direction is carried by the colour and by which
            -- side of the fill the tick lands on, so the number itself needn't be signed. Read off the
            -- true current, never the lagging bar value, so it never quotes a figure mid-drain.
            local after = math.max(0, math.min(r.effMax, r.trueCur + r.delta))
            self.poolCallouts:add({
                anchorX = barX + barW * afterRatio, anchorY = rowY, barH = barH,
                key = r.res.key, alpha = alpha,
                text = tostring(math.floor(after + 0.5)),
                color = (r.delta > 0 and Colors.HEALING) or (r.lethal and Colors.LETHAL) or Colors.PENDING,
            })
        end
        Theme.set(Theme.ink, alpha)
        love.graphics.printf(r.text, rx + rw - valueColW, rowY + (barH - self.smallFont:getHeight()) / 2,
            valueColW, "right")
    end
end

function CombatPanel:drawEntry(entry, ey, num, h, alpha, w)
    local unit = entry.unit
    local ex = self.x + 8
    local ew = w or (self.w - 16)

    -- Preview ghost: a faded, dashed hypothetical slot showing where the actor would land, not stats.
    -- Ghosts are NOT always ours -- a foe mid-channel projects its follow-up slot, and a stun/freeze
    -- projects the shoved TARGET's delayed slot -- so the card has to say whose future this is. A real
    -- card carries that in its HP bar; a ghost shows no stats, so faction rides on the dash, the
    -- portrait ring and the name instead (blue ours / green uncommanded / red theirs).
    if entry.preview then
        local fc = self:unitColor(unit)
        local pl = Theme.panel2
        love.graphics.setColor(lerp(pl[1], fc[1], 0.18), lerp(pl[2], fc[2], 0.18),
            lerp(pl[3], fc[3], 0.18), 0.5)
        love.graphics.rectangle("fill", ex, ey, ew, h, 6, 6)
        love.graphics.setLineWidth(1)
        self:dashedRect(ex, ey, ew, h, nil, fc)
        self:drawInitiative(entry, ex, ew, ey, nil)
        local ps = h - 6
        local px, py = ex + NUM_GUTTER, ey + 3
        self:drawPortrait(unit, px, py, ps, 0.55)
        -- The same faction ring the acting card wears on its portrait, so ghost and real card mark
        -- side identically.
        love.graphics.setColor(fc[1], fc[2], fc[3], 0.75)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, ps, ps, 4, 4)
        love.graphics.setLineWidth(1)
        local rx = ex + NUM_GUTTER + ps + 8
        love.graphics.setFont(self.nameFont)
        -- The side hue lifted toward white, the same trick the pool tags use, so a deep enamel red or
        -- blue still reads as a name at this size.
        love.graphics.setColor(fc[1] * 0.6 + 0.28, fc[2] * 0.6 + 0.28, fc[3] * 0.6 + 0.28, 0.95)
        love.graphics.print(unit.char.name or "?", rx, ey + 3)
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted, 0.95)
        -- "NEXT TURN HERE", not "would act here". The old wording put the ACTION at this slot -- hover
        -- Wait and it read as though the waiting happened down there rather than now -- when what the
        -- row actually marks is where the body comes round AGAIN, having paid for the thing it is
        -- about to do this instant. The conditional goes with it: "would" is already said by the
        -- dashed border, which is how every hypothetical on this strip announces itself, and none of
        -- the labelled ghosts beside it ("channel resolves here", "then acts here") hedges either.
        love.graphics.print(entry.previewLabel or "next turn here", rx, ey + 18)
        return
    end

    -- A real card. p = 0 is the slim upcoming look, p = 1 the tall framed current card. `forceProm`
    -- (the fading frame card in an "out" hand-off) pins it full-height regardless of cardProm.
    local isCurrent = (unit == self.view.current)
    -- The HELD read (see :shownParty): a body the model has just charmed still reads as ours until the
    -- blow that took it is seen to land, so its card does not start wearing an enemy intent icon while
    -- the thing that turned it is still walking in.
    local isParty = self:shownParty(unit)
    -- Is this card the body the fight is about? Asked of the model, which is the same question the
    -- board asks for its nameplate and heavy bar (Combat.isBoss), so the two surfaces cannot disagree.
    local isBoss = Combat.isBoss(self.combat, unit)
    local p = entry.forceProm or self.cardProm[unit] or (isCurrent and 1 or 0)
    -- Top-anchored: the card hangs from its slot top (ey) and its height grows with p, so a card
    -- dropping into the frame slides its top down and fills the slot as it arrives.
    local dh = SLIM_H + (h - SLIM_H) * p
    local dy = ey
    -- A card that just handed off its turn MORPHS in from its preview ghost: its content fades up
    -- (ca 0.35 -> 1) as `solidify` runs down, so the faded ghost visibly becomes the real card. An
    -- explicit `alpha` (the outgoing's fading frame card) overrides that.
    -- `solidify` now carries only the ghost's dashes dissolving as this card lands in the slot that
    -- ghost was holding. Its content does NOT fade up any more: the card was on screen a moment ago
    -- and has merely travelled, and fading it would be losing sight of the very thing being followed.
    local sd = self.solidify[unit]
    local ca = alpha or 1

    -- Plate: a slate card inset (panel2), lightening toward the panel surface as it grows current so
    -- the acting card reads as raised. The BORDER is bone-gold TRIM, not faction -- faction already
    -- lives in the HP bar (Colors.side), so the strip reads as one etched plate rather than a stack of
    -- red/blue boxes (matching the mock). The "Current Turn" frame (drawActivePanel) brackets the actor.
    local s0, s1 = Theme.panel2, Theme.panel
    love.graphics.setColor(lerp(s0[1], s1[1], p), lerp(s0[2], s1[2], p), lerp(s0[3], s1[3], p),
        lerp(0.85, 1, p) * ca)
    love.graphics.rectangle("fill", ex, dy, ew, dh, 4, 4)
    love.graphics.setLineWidth(1)
    -- The border blends from the quiet default frame (an upcoming card) to the SPOTLIGHT gold as the
    -- card grows current -- so the acting unit's plate is the one place the bright accent appears in the
    -- strip, and the eye lands on it. An upcoming card stays a dim bronze edge.
    local fr, ac = Theme.frame, Theme.accentAmber
    Theme.set({ lerp(fr[1], ac[1], p), lerp(fr[2], ac[2], p), lerp(fr[3], ac[3], p) }, lerp(0.35, 1.0, p) * ca)
    love.graphics.rectangle("line", ex, dy, ew, dh, 4, 4)
    -- Carved corner ornaments on the acting card only (the mock's `.current` engraved plate), fading in
    -- as the card grows current so a slim upcoming card stays plain -- in the same spotlight gold.
    if p > 0.6 then Theme.corners(ex, dy, ew, dh, 8, { ac[1], ac[2], ac[3], (p - 0.6) / 0.4 * ca }) end

    self:drawInitiative(entry, ex, ew, dy, self.tempo[unit])

    -- A unit winding up a channel (never the current card -- that's the caster surfacing to detonate,
    -- framed with full pools already): its real card holds the resolve slot for the whole wind-up, so
    -- it names the pending SPELL and cues "channel resolves here" instead of stats, matching the ghost
    -- the aim preview showed. It stays slim, so no prominence blend applies.
    if unit.channel and not isCurrent then
        local ps = dh - 6
        local px, py = ex + NUM_GUTTER, dy + 3
        self:drawTurnNumber(num, ex, dy, dh, 0)
        self:drawPortrait(unit, px, py, ps, 1)
        -- This card spends its name row on the SPELL and its bar row on the wind-up cue, so it carries
        -- no HP bar to say whose cast is landing. The faction ring stands in, the same mark the ghost
        -- and the acting card wear.
        local fc = self:unitColor(unit)
        love.graphics.setColor(fc[1], fc[2], fc[3], 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, ps, ps, 4, 4)
        love.graphics.setLineWidth(1)
        local rx = ex + NUM_GUTTER + ps + 8
        love.graphics.setFont(self.nameFont)
        love.graphics.setColor(0.640, 0.511, 0.822) -- arcane violet, matching the Channeling badge tint
        love.graphics.print(unit.channel.item.name or "Channeling", rx, dy + 3)
        love.graphics.setFont(self.smallFont)
        local iconW = 7
        self:drawHourglass(rx, dy + 21, iconW, 9, 0.640, 0.511, 0.822, 0.9)
        love.graphics.setColor(0.640, 0.511, 0.822, 0.9)
        love.graphics.print("channel resolves here", rx + iconW + 4, dy + 20)
        for _, r in ipairs(self:statusBadgeRects(unit, ex, ew, dy)) do
            StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
        end
        return
    end

    -- Portrait + name sized by prominence; content alpha (ca) fades a just-handed-off card up.
    local ps = dh - lerp(6, 12, p)
    local px, py = ex + NUM_GUTTER, dy + lerp(3, 6, p)
    self:drawPortrait(unit, px, py, ps, ca)
    -- Faction ring on the acting card's portrait (the mock's `.current .big` inset ring): with the card
    -- border now bone-gold trim, faction rides here as a portrait accent -- blue ours / red theirs.
    -- Fades in with prominence so a slim upcoming card's portrait stays plain.
    if p > 0.5 then
        local fc = self:unitColor(unit)
        love.graphics.setColor(fc[1], fc[2], fc[3], (p - 0.5) / 0.5 * ca)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, py, ps, ps, 4, 4)
        love.graphics.setLineWidth(1)
    end
    self:drawTurnNumber(num, ex, dy, dh, p)

    local rx = ex + NUM_GUTTER + ps + lerp(8, 10, p)
    local rw = ex + ew - rx - lerp(8, 10, p)
    -- The predicted intent (models/intent.lua) for a foe's SLIM card: what it will do this round and to
    -- whom, read off the shared cache the state feeds in. Only foes (never our own), never the acting
    -- card (its intent is moot -- it acts now), and it fades out as a card grows into the current frame
    -- (p rising), so the read lives on the upcoming strip alone. When shown, it reserves a right-hand
    -- column so the HP bar stops short of it rather than running underneath.
    local intent = (not isCurrent) and (not isParty) and self.view.intents and self.view.intents[unit]
    if intent and p < 0.5 then rw = rw - INTENT_COL end
    -- Name: the slim card's font, promoting to the head font on the current card (like drawTurnNumber);
    -- colour warms to gold. We swap between two native faces rather than scaling one -- fonts are never
    -- scaled (a scaled bitmap font blurs), so the steady acting card stays crisp.
    love.graphics.setFont((p > 0.5) and self.headFont or self.nameFont)
    local nameX = rx
    -- THE FIGHT'S OWN CREST, on the card of the body the fight is named after. The strip is where the
    -- boss was hardest to pick out: every card is the same plate at the same height, faction lives in a
    -- bar, and a general and an imp differed by the word in the name row alone. The mark is the one
    -- already flanking the encounter's title at the top of the screen (states/battle.lua's
    -- drawEncounterLines), so the card carrying it reads as "this is the thing up there" rather than as
    -- a fourth kind of badge to learn.
    --
    -- Deliberately NOT another coloured ring or border: the card's edge is already spoken for three
    -- times over -- spotlight gold for whoever is acting, a white pulse for a hovered log line, cyan
    -- for the body under the cursor on the board -- and a fourth would be the one that stops meaning
    -- anything. An ornament in the name row collides with none of them.
    if isBoss then
        local ch = love.graphics.getFont():getHeight()
        Theme.crest(rx + 5, dy + lerp(4, 8, p) + ch / 2, 5, { Theme.accentAmber[1], Theme.accentAmber[2],
            Theme.accentAmber[3], ca })
        nameX = rx + 15
    end
    Theme.set(Theme.ink, ca)
    love.graphics.print(unit.char.name or "?", nameX, dy + lerp(4, 8, p))

    for _, r in ipairs(self:statusBadgeRects(unit, ex, ew, dy)) do
        StatusBadge.draw(r.st, r.x, r.y, r.w, r.h)
    end

    -- Resource read-out: the current card shows the full numbered HP/MP/SP stack; a slim card shows just
    -- the thin HP bar. (ca fades either while a handed-off card morphs in.)
    --
    -- THE TWO CROSS-FADE ON ONE CURVE, AND IT IS NOT `p`. The pool stack used to come up in step with
    -- the plate's growth, which put three numbered rows in the air while the card was still moving --
    -- and, because their offsets were constants sized for a finished card, hanging out through the
    -- bottom border on the way. Now the stack holds off until the last third of the arrival (poolA)
    -- and the thin bar holds the row until it does, so one read is always complete rather than two
    -- half-drawn ones. `barRow` is the line they share, so the bar does not jump when it hands over.
    local poolA = clamp01((p - 0.66) / 0.34)
    local barRow = lerp(22, 34, p)
    local hp = unit.char.stats.health
    if (1 - poolA) > 0.02 and type(hp) == "table" and (hp.max or 0) > 0 then
        local pv = self.view.preview and self.view.preview[unit]
        local delta = pv and ((pv.heal or 0) - (pv.damage or 0)) or 0
        local reserved = Combat.reservedAmount(unit.char, "health")
        local effMax = Combat.unreservedMax(unit.char, "health") + reserved
        drawResourceBar(rx, dy + barRow, rw, 6, self:shownHealth(unit), effMax, self:unitColor(unit),
            delta, pv and pv.lethal, reserved, (1 - poolA) * ca,
            isBoss and Combat.bossThresholds(unit) or nil)
    end
    if poolA > 0.02 then
        -- Three rows, a 9px bar each, inside the height the plate HAS -- not the height it will have.
        -- The pitch closes up rather than letting the last row cross the border, and never opens past
        -- the full-size pitch.
        local pitch = math.min(POOL_PITCH, math.max(6, (dh - barRow - 9 - 4) / 2))
        self:drawPoolBars(unit, rx, rw, dy + barRow, poolA * ca, pitch)
    end

    -- The intent read sits in the reserved right column, on the HP-bar row (which was shortened to
    -- make room) rather than the top -- the top-right holds the initiative read-out and the status
    -- badges, and the lower-right is otherwise empty. Fades as the card grows current.
    if intent and (1 - p) > 0.5 then
        self:drawIntentRead(intent, ex + ew - 6, dy + dh - 9, (1 - p) * ca)
    end

    -- The ghost's dashed border dissolves out as the card solidifies, so a card that had a preview
    -- visibly turns from ghost into real. Only for the real queue card (not the fading frame card,
    -- `alpha`) and only for a card that actually had a ghost (dashed = true).
    if sd and sd.dashed and sd.t > 0.02 and not alpha then
        self:dashedRect(ex, dy, ew, dh, 0.9 * sd.t, self:unitColor(unit))
    end
end

-- A foe's predicted intent (models/intent.lua) on its turn-order card: the kind glyph plus the number
-- the blow carries, laid right-to-left ending at `rightX` and centred on `cy`. The number is the
-- damage a strike or spell lands, or the healing a support cast gives -- the same deterministic
-- figure the aimed-action HP-bar preview shows, so the timeline quotes a number the player already
-- trusts. A debuff or a hold shows the icon alone (the mark itself says "status" / "coming for
-- nobody"). Tinted by the intent's kind, matching its target line on the board.
function CombatPanel:drawIntentRead(intent, rightX, cy, alpha)
    local kind = intent.kind or "wait"
    local col = Colors.INTENT[kind] or Colors.RANGE
    local glyph = Glyphs.INTENT[kind] or Glyphs.INTENT.wait
    local n
    if kind == "attack" or kind == "cast" then
        if intent.amount and intent.amount > 0 then n = math.floor(intent.amount + 0.5) end
    elseif kind == "support" then
        if intent.heal and intent.heal > 0 then n = math.floor(intent.heal + 0.5) end
    end
    local x = rightX
    if n then
        love.graphics.setFont(self.smallFont)
        local text = tostring(n)
        love.graphics.setColor(col[1], col[2], col[3], alpha)
        love.graphics.print(text, x - self.smallFont:getWidth(text), cy - self.smallFont:getHeight() / 2)
        x = x - self.smallFont:getWidth(text) - 3
    end
    local iconW = 10
    glyph(x - iconW, cy - iconW / 2, iconW, iconW, col[1], col[2], col[3], alpha)
end

-- Small hourglass glyph (two triangles) for the speed badge, drawn in the given box. Kept as a method
-- for its callers' sake; the glyph itself lives in ui/glyphs.lua, since the item tooltip quotes a
-- recovery with the same mark.
function CombatPanel:drawHourglass(x, y, w, h, r, g, b, a)
    Glyphs.hourglass(x, y, w, h, r, g, b, a)
end

-- Small padlock (shackle arc over a body) for the reserve badge: the resource this ability locks
-- away, told apart from the cost glyphs because it never comes back on its own.
--
-- The shape moved to ui/glyphs.lua when the vendor's shut tiles wanted it too, the same way the
-- hourglass above did: one mark, drawn once, however many things are shut.
function CombatPanel:drawLock(x, y, w, h, r, g, b, a)
    Glyphs.padlock(x, y, w, h, r, g, b, a)
end

-- A summoning circle with something bound inside it: the glyph for an ability whose creature is
-- still on the field, and so cannot be cast again until it falls. A ring around a core dot -- at
-- this size (9x10) a literal figure-in-a-circle silts up into a blob, while two concentric shapes
-- with clear space between them stay legible.
function CombatPanel:drawSummonRing(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, cy = x + w / 2, y + h / 2
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, math.min(w, h) * 0.46)
    love.graphics.setLineWidth(1)
    love.graphics.circle("fill", cx, cy, math.min(w, h) * 0.16)
end

-- A four-point star: the mark of a SIGNATURE ability still charging toward its in-battle unlock
-- (land N blows, heal N times, weather a hit). Told apart from the padlock beside it -- a reserve is
-- a resource locked AWAY, a sigil is a move not yet EARNED -- and from the hourglass, which is ticks.
-- Its badge label is the progress toward the requirement (3/5).
function CombatPanel:drawSigil(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, cy = x + w / 2, y + h / 2
    local o, i = math.min(w, h) * 0.5, math.min(w, h) * 0.19
    love.graphics.polygon("fill",
        cx, cy - o, cx + i, cy - i, cx + o, cy, cx + i, cy + i,
        cx, cy + o, cx - i, cy + i, cx - o, cy, cx - i, cy - i)
end

-- The resource glyphs live in ui/glyphs.lua: the pool bars below and ui/tile_tooltip.lua mark their
-- HP/MP/SP rows with the same three shapes, so a pool reads the same wherever it's quoted. A cost
-- badge names its resource as its icon kind, so an unknown stat (a mod's own pool) still gets a mark
-- -- the gem, the generic "some resource" shape.
local RES_GLYPH = Glyphs.RESOURCE

-- Two stubs with a gap between them: a "broken link" glyph marking an adjacency requirement the
-- grid doesn't satisfy (a met one is drawn as a solid connector line over the grid instead).
function CombatPanel:drawBrokenLink(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y + h, x + w * 0.30, y + h * 0.58)
    love.graphics.line(x + w * 0.70, y + h * 0.42, x + w, y)
    love.graphics.setLineWidth(1)
end

-- A cost/speed corner badge: a dark pill with an icon and a label. `corner` is "left"
-- (top-left costs) or "right" (top-right speed); `iconKind` is "hourglass", "lock", "link", "ring",
-- or a resource name ("mana"/"stamina"/"health") for a cost badge, which draws that pool's glyph.
-- `row` stacks a badge under the previous one in the same corner (0 = top, the default).
function CombatPanel:drawBadge(sx, sy, sw, corner, iconKind, amount, color, a, row)
    local bw, bh = self:badgeSize(amount)
    local pad = 3
    -- The fallback for a slot too narrow to hold two badges side by side (self.badgeStack, set in
    -- relayout): the right-hand one drops to the BOTTOM-LEFT so the pair cannot meet whatever the
    -- numbers are. It costs the icon its left half, which is why the column is sized to avoid it --
    -- but a space can always get narrow enough, and overlapping badges are worse than a covered icon.
    -- There is room for the second row only because the name band is gone on a handheld: 3..28 for
    -- the top, 30..55 for the bottom, in a 58-tall slot.
    if self.badgeStack and corner == "right" then
        self:drawBadgeAt(sx + pad, sy + (self.slotH or bh) - pad - bh, iconKind, amount, color, a)
        return
    end
    local bx = (corner == "right") and (sx + sw - pad - bw) or (sx + pad)
    self:drawBadgeAt(bx, sy + pad + (row or 0) * (bh + 2), iconKind, amount, color, a)
end

-- The box `amount`'s badge will fill, so a caller that is NOT putting one in a corner -- the recovery
-- clock, which centres its badge on the icon -- can place it before drawing it.
function CombatPanel:badgeSize(amount)
    return self.badgePadX * 2 + self.badgeIconW + self.badgeGap
        + self.badgeFont:getWidth(tostring(amount)), self.badgeH
end

-- The badge proper, at an explicit position: what both the corner badges above and the centred
-- recovery clock draw through, so every pill in the grid is built the same way.
function CombatPanel:drawBadgeAt(bx, by, iconKind, amount, color, a)
    love.graphics.setFont(self.badgeFont)
    local label = tostring(amount)
    local iconW, gap, padX = self.badgeIconW, self.badgeGap, self.badgePadX
    local bw, bh = self:badgeSize(amount)

    love.graphics.setColor(0.06, 0.07, 0.10, 0.82 * (a or 1))
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

    local ix = bx + padX
    -- The glyph is a proportion of the pill rather than a fixed 10, so a bigger pill gets a bigger
    -- icon instead of a small one adrift in it.
    local glyphH = math.floor(self.badgeH * 0.56)
    local iy = by + (bh - glyphH) / 2
    if iconKind == "hourglass" then
        self:drawHourglass(ix, iy, iconW, glyphH, color[1], color[2], color[3], a)
    elseif iconKind == "lock" then
        self:drawLock(ix, iy, iconW, glyphH, color[1], color[2], color[3], a)
    elseif iconKind == "link" then
        self:drawBrokenLink(ix, iy, iconW, glyphH, color[1], color[2], color[3], a)
    elseif iconKind == "ring" then
        self:drawSummonRing(ix, iy, iconW, glyphH, color[1], color[2], color[3], a)
    elseif iconKind == "sigil" then
        self:drawSigil(ix, iy, iconW, glyphH, color[1], color[2], color[3], a)
    elseif iconKind == "charges" then
        Glyphs.charges(ix, iy, iconW, glyphH, color[1], color[2], color[3], a)
    else -- a cost: `iconKind` is the resource it's paid in, and each pool has its own shape
        local glyph = RES_GLYPH[iconKind] or Glyphs.manaGem
        glyph(ix, iy, iconW, glyphH, color[1], color[2], color[3], a)
    end

    love.graphics.setColor(0.96, 0.96, 0.98, a or 1)
    love.graphics.print(label, ix + iconW + gap, by + (bh - self.badgeFont:getHeight()) / 2)
end

function CombatPanel:drawItemGrid()
    love.graphics.setFont(self.smallFont)
    -- The header is normally "Actions"; while a chargeable signature is aimed it becomes its wind-up
    -- read-out instead, in the gold the timeline wears (this IS a count of ticks): how long the blow
    -- is being held, out of the deepest hold the ability allows. ONE pair of numbers rather than the
    -- old "+extra out of max, lands in base+extra" -- since the wind-up fields folded the depth and
    -- the time it buys are the same quantity. Wheel / +- / bumpers tune it (battle.lua).
    local wu = self.view.armedWindup
    if wu then
        Theme.set(Theme.accentAmber)
        love.graphics.printf(string.format("Wind-up %d/%d  (lands in %d)", wu.ticks, wu.max, wu.ticks),
            self.x, self.gridY - 24, self.w, "center")
    else
        love.graphics.setFont(self.captionFont)
        -- Center the caption in the gap between the acting card (bottom at stripBottom) and the grid
        -- top, so it carries equal breathing room above and below.
        local capY = self.stripBottom + (self.gridY - self.stripBottom - self.captionFont:getHeight()) / 2
        Theme.caption("Actions", self.x, capY, self.w)
        love.graphics.setFont(self.smallFont)
    end

    local isPartyTurn = self.view.isPartyTurn
    local items = self.view.items or {}
    local NAME_H = 16

    -- Slot plates, then the adjacency connectors across them (a Fire Stone's aura, Omnislash
    -- scaling off adjacent weapons, Rain of Arrows' bow requirement), tinted by relationship kind
    -- to match the loadout legend. Both go down before the item contents, so a wire reads over the
    -- plate but never covers an icon, a badge or a name.
    Theme.set(Theme.slot, isPartyTurn and 1 or 0.5)
    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 5, 5)
    end
    self:drawAdjacencyLinks()

    for i = 1, COLS * ROWS do
        local sx, sy, sw, sh = self:slotRect(i)
        local item = items[i]
        local armed = item and item == self.view.armedItem
        -- An ability the actor can't activate -- can't pay for, spent stack, missing the neighbor it
        -- requires -- is grayed out, and the badge naming the reason (below) is drawn red at full
        -- alpha to point at it. Only on a party turn: off-turn slots dim for a different reason, and
        -- the hover tooltip spells the reason out either way.
        local blocked = isPartyTurn and self:blockReason(item) or nil
        -- A Blink (moveBehavior) item is activatable too, even though it has no ability: clicking it
        -- toggles teleport movement rather than arming a cast.
        local isBlink = item and item.moveBehavior ~= nil
        local usable = item and (item.activeAbility ~= nil or isBlink) and isPartyTurn and not blocked
        -- A triggered reflex that has fired and is still on cooldown. Not a blockReason: nothing here
        -- is being cast, so there is no arm to refuse -- the slot simply cannot answer yet.
        local cooling = item and self.view.current and Combat.itemCooldown(self.view.current, item)
        -- ...but a spent reflex may only speak for the WHOLE slot when the slot has nothing else
        -- to offer. Grey out a sword because its parry is on cooldown and the panel tells a flat lie:
        -- the sword is right there and swinging it is legal. Counters have no cooldown at all any more
        -- (models/trait.lua prices an answer instead of timing it), so in practice only passive
        -- utilities reach this branch -- the guard is here so it stays that way.
        local inert = cooling and not usable

        if item then
            -- Grayer than an ordinary idle slot: a reflex-only item on cooldown is inert in a
            -- way a merely passive one isn't, so it must not read as ready at a glance.
            local dim = inert and 0.3 or ((not usable) and 0.45 or 1)
            local ab = item.activeAbility

            -- Icon fills the slot; the badges and name overlay its corners/bottom. Except where the
            -- badges STACK (see relayout's badgeGutter): a pill down the left edge top and bottom
            -- covers a centred icon almost entirely, so there the icon draws in the plate to the
            -- right of the gutter and is fully visible at the smaller size.
            local sprite = item.sprite
            local iconX, iconW = sx + self.badgeGutter, sw - self.badgeGutter
            local icx, icy = iconX + iconW / 2, sy + sh / 2
            if type(sprite) == "userdata" then
                love.graphics.setColor(dim, dim, dim)
                local iw, ih = sprite:getDimensions()
                local scale = math.min((iconW - 8) / iw, (sh - 8) / ih)
                love.graphics.draw(sprite, icx, icy, 0, scale, scale, iw / 2, ih / 2)
            else
                -- Art missing: a rounded placeholder with the item's initial.
                local ph = math.min(sh - 10, iconW - 6)
                love.graphics.setColor(0.55 * dim, 0.55 * dim, 0.60 * dim)
                love.graphics.rectangle("fill", icx - ph / 2, icy - ph / 2, ph, ph, 5, 5)
                love.graphics.setFont(self.headFont)
                love.graphics.setColor(dim, dim, dim)
                love.graphics.printf((item.name or "?"):sub(1, 1), icx - ph / 2, icy - 12, ph, "center")
            end

            -- The cooldown clock over the icon (never over the name band, which stays readable): the
            -- wedge, then the ticks left in an hourglass badge centred on it. Centred rather than
            -- tucked in a corner because the clock is the whole story of a spent slot -- it is
            -- what the eye should land on, not a footnote to the art behind it. Red, like every other
            -- badge that says "not yet".
            if inert then
                local cwx, cwy = sx + 1, sy + 1
                local cww, cwh = sw - 2, sh - NAME_H - 1
                drawCooldownSweep(cwx, cwy, cww, cwh, cooling.remaining / cooling.total)
                local left = math.max(0, math.ceil(cooling.remaining))
                local bw, bh = self:badgeSize(left)
                self:drawBadgeAt(cwx + (cww - bw) / 2, cwy + (cwh - bh) / 2,
                    "hourglass", left, WARN_COLOR, 1)
            elseif cooling then
                -- On cooldown, but the slot can still ACT: the clock is news about one reflex on the
                -- item, not a verdict on the item, so it rides in a corner badge like every other
                -- qualifier instead of covering the art. Red under the gold speed badge -- the same
                -- hourglass, because both are ticks, and the colour carries the difference between
                -- "this is how long it takes" and "this is how long until".
                local left = math.max(0, math.ceil(cooling.remaining))
                self:drawBadge(sx, sy, sw, "right", "hourglass", left, WARN_COLOR, 1,
                    (ab and ab.speed) and 1 or 0)
            end

            -- Name band overlaid along the bottom, single line scaled to fit.
            --
            -- NOT ON A HANDHELD, where the panel is a 262px column and a slot is 71 of it. The type
            -- floor left about 61px for a name that wants 78, so every band read "Iron S...",
            -- "Leath...", "Clear..." -- three ellipses telling the player nothing three icons had
            -- already told them. The obvious fix is a wider slot and it is not available: the 3x3 is
            -- a MECHANIC, not a display choice (Combat.adjacencyLinks -- neighbouring cells form
            -- auras, boosts and requirements), so the grid cannot be reshaped to fit the actions a
            -- unit happens to carry, and widening the column would un-centre the board.
            --
            -- So the band goes instead, and it is the right thing to lose: it is optional detail. The
            -- icon says which item this is, the corner badges say what it costs, and the NAME is what
            -- you want while deciding -- which is when the slot is armed, and battle.drawHudText
            -- prints it whole in the column where there is room.
            if not Scale.inHandheldSpace then
                love.graphics.setColor(0, 0, 0, 0.6 * dim)
                love.graphics.rectangle("fill", sx + 1, sy + sh - NAME_H, sw - 2, NAME_H - 1, 0, 0, 5, 5)
                -- One size for every slot in the grid, on a native font (never scaled); a name too
                -- long for the band ellipsizes. The sans data face, not the serif.
                local font, name = Theme.itemTileName(item.name or "?", sw - 8)
                love.graphics.setFont(font)
                local nw, nh = font:getWidth(name), font:getHeight()
                love.graphics.setColor(0.94 * dim + 0.05, 0.94 * dim + 0.05, 0.96 * dim + 0.05)
                love.graphics.print(name, sx + sw / 2 - nw / 2, sy + sh - NAME_H + (NAME_H - nh) / 2)
            end

            -- Stack count ("xN") for a stackable consumable, in a pill just above the name band so
            -- it clears the top-corner cost/speed badges. Shown for any real stack (>1) and for a
            -- spent one (x0, tinted red) so an empty-but-kept slot reads as out of stock.
            local qty = item.quantity or 1
            if qty ~= 1 then
                love.graphics.setFont(self.smallFont)
                local label = "x" .. qty
                local tw = self.smallFont:getWidth(label)
                local bw, bh = tw + 8, 15
                local bx, by = sx + sw - 3 - bw, sy + sh - NAME_H - bh - 1
                love.graphics.setColor(0.06, 0.07, 0.10, 0.85 * dim)
                love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
                if qty <= 0 then love.graphics.setColor(WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3], 1)
                else love.graphics.setColor(0.96, 0.96, 0.98, dim) end
                love.graphics.print(label, bx + 4, by + 1)
            end

            -- What the cast takes (top-left, stacked downward) + speed (top-right), for ability
            -- items only. A badge whose demand is the one blocking the cast flips to red at full
            -- alpha, so it reads as the reason the slot is grayed out.
            --
            -- `row` is hoisted out of the ability branch because ONE of these badges belongs to items
            -- with no ability at all: a charge pool's count. Five of the ten pool items are pure
            -- passive bankers (the Crusader's Tabard, the Vow of the March) whose entire job is to
            -- accrue -- exactly the slots that most need their number on screen, and exactly the ones
            -- an `if ab` gate would have hidden it from.
            local row = 0
            if ab then
                -- A badge per pool the cast draws on, stacked in authored order, so a weapon paid for
                -- in two shows two. Only the pool that is actually short flips to red -- with two
                -- badges up, reddening both would blame a pool the caster can well afford. Priced
                -- through Combat.abilityCosts (not raw Item.costs) so the badge carries the actor's
                -- status cost multiplier -- a Mired unit's swing reads doubled, matching the gate that
                -- refuses it and the tooltip that quotes it.
                local costs = self.view.current and Combat.abilityCosts(self.view.current, ab)
                    or Item.costs(ab)
                for _, cost in ipairs(costs) do
                    local short = blocked and blocked.kind == "cost" and blocked.stat == cost.stat
                    local c = short and WARN_COLOR or (RES_COLOR[cost.stat] or COST_FALLBACK)
                    self:drawBadge(sx, sy, sw, "left", cost.stat, cost.amount, c, short and 1 or dim, row)
                    row = row + 1
                end
                -- A reservation is a cost too -- paid on the cast, then locked away for as long as
                -- what it summons lives -- so it earns its own badge under the cost, a padlock
                -- instead of the resource's own glyph. Priced against the actor (a share of ITS maximum),
                -- falling back to the raw percentage when there's nobody to price it for.
                if ab.reserve then
                    local short = blocked and blocked.kind == "reserve"
                    local c = short and WARN_COLOR or (RES_COLOR[ab.reserve.stat] or COST_FALLBACK)
                    local res = self.view.current and Combat.abilityReserve(self.view.current, ab)
                    local label = res and res.amount
                        or (math.floor((ab.reserve.percent or 0) * 100 + 0.5) .. "%")
                    self:drawBadge(sx, sy, sw, "left", "lock", label, c, short and 1 or dim, row)
                    row = row + 1
                end
                -- A charge/counter item's purse (the Gleaning Rod, the Reliquary of Tallies): what it
                -- currently holds, in its own lavender badge under the cost, so the count reads at a
                -- glance -- and shows 0, red, when empty (the same state that greys the slot and refuses
                -- the click, blocked.kind == "empty"). Always drawn when the ability declares a counter,
                -- so an emptying purse never blinks from a number straight to blank.
                if ab.counter then
                    local n = ab.counter(self.view.current, item) or 0
                    -- Red only when a zero count actually REFUSES the cast (a spent purse). A non-gating
                    -- counter -- the Long Count's turn tally -- reads 0 as a floor to grow from, so it
                    -- stays lavender rather than alarming the player about a slot that works fine.
                    local empty = n <= 0 and ab.counterGates ~= false
                    self:drawBadge(sx, sy, sw, "left", "charges", n,
                        empty and WARN_COLOR or COUNTER_COLOR, empty and 1 or dim, row)
                    row = row + 1
                end
            end
            -- A CHARGE POOL's count, in the same lavender badge as the purse above and for the same
            -- reason: a resource that accrues has to be readable, or the decision these items exist to
            -- ask -- spend now, or bank one more turn -- is being asked off a number the player cannot
            -- see. Covers Zeal, Defiance, Tempo, Arcane and the monk's chi at once, since
            -- Combat.itemChargeKey finds the pool whether the item declares it or only spends it.
            --
            -- OUTSIDE the ability branch, which is the whole point: five of the ten pool items carry no
            -- ability at all (the Crusader's Tabard, the Vow of the March, the Arcane Conduit), and a
            -- pure banker is precisely the slot whose only visible job is the number.
            --
            -- Quoted as n/max where a purse quotes a bare n, and the ceiling is not decoration: banking
            -- past a full pool is silently DISCARDED (Combat.chargePool caps), so "am I about to waste
            -- this" is a question only the max answers. The MERGED cap, so a Crusader wearing two Zeal
            -- charms is told the deeper one they actually bank into rather than one file's figure.
            --
            -- Never red. An empty purse is an error state -- it refuses the cast -- but a pool at zero
            -- is just an early turn, and the lock badge already speaks for a spender that is not ready
            -- yet. Lavender throughout keeps "banked resource" one colour wherever it is quoted.
            if not (ab and ab.counter) then
                local n, max = Combat.itemChargeReadout(self.view.current, item)
                -- ...and failing that, a stacking TRAIT's count (Trait.stackReadout): the Butcher's
                -- Tally, the Blood Fever Mail. Third and last because it is the narrowest source, but
                -- it is the one that reaches items with no ability at all to hang a counter on. Same
                -- badge, same n/max, since a full stack discards the next body exactly as a full pool
                -- discards the next point.
                if not n then n, max = Trait.stackReadout(self.view.current, item) end
                if n then
                    self:drawBadge(sx, sy, sw, "left", "charges", n .. "/" .. max, COUNTER_COLOR, dim, row)
                    row = row + 1
                end
            end
            if ab then
                if ab.speed then
                    self:drawBadge(sx, sy, sw, "right", "hourglass", ab.speed, SPEED_COLOR, dim)
                end
                -- An unmet adjacency requirement (Rain of Arrows with no bow beside it) names the
                -- missing neighbor in a red broken-link badge, tucked under the cost badges.
                if blocked and blocked.kind == "adjacency" then
                    local req = ab.requiresAdjacent
                    self:drawBadge(sx, sy, sw, "left", "link", req.tag or req.type or "item",
                        WARN_COLOR, 1, row)
                end
                -- The creature this ability called is still standing, so it cannot be cast again:
                -- a red summoning-ring badge under the cost badges says the ability is ACTIVE rather
                -- than unaffordable. A timed summon counts down in the badge instead (bare ticks, the
                -- same way every other duration in the game is quoted). The hover tooltip names it.
                if blocked and blocked.kind == "active" then
                    local left = blocked.summon.summonRemaining
                    local label = left and math.max(0, math.ceil(left)) or "Active"
                    self:drawBadge(sx, sy, sw, "left", "ring", label, WARN_COLOR, 1, row)
                end
                -- A signature still charging toward its in-battle requirement: a star badge under the
                -- cost badges shows the progress (3/5), red like every other "not yet". The hover
                -- tooltip spells the requirement out ("Weather 4 blows (3/5)").
                if blocked and blocked.kind == "locked" then
                    local label = (blocked.total and blocked.total > 0)
                        and ((blocked.cur or 0) .. "/" .. blocked.total) or "Locked"
                    self:drawBadge(sx, sy, sw, "left", "sigil", label, WARN_COLOR, 1, row)
                end
            end
        end

        -- Border: armed strike (red) / armed support (green), a toggled-on Blink (violet), hovered
        -- (gold), usable (blue), else idle.
        local blinkOn = isBlink and self.view.current and self.view.current.blinkArmed
        if armed then
            if Combat.isHarmlessAbility(item.activeAbility) then
                love.graphics.setColor(0.40, 0.68, 0.73) -- harmless armed (a foe read, not struck)
            elseif Combat.isSupportAbility(item.activeAbility) then
                love.graphics.setColor(0.35, 0.85, 0.40) -- support armed (heal / buff)
            else
                love.graphics.setColor(0.85, 0.35, 0.35) -- offensive armed (strike / trap)
            end
        elseif blinkOn then love.graphics.setColor(0.60, 0.45, 0.95) -- Blink toggled on (violet)
        elseif usable and self.hoverIndex == i then Theme.set(Theme.accentAmber) -- hovered
        -- A signature that has met its requirement and is ready to unleash: an amber border set apart
        -- from an ordinary usable slot's blue, so the eye catches the moment it comes online.
        elseif usable and item and item.activeAbility and item.activeAbility.unlock then
            love.graphics.setColor(0.95, 0.72, 0.28)
        elseif usable then Theme.set(Theme.frame)      -- ready: full bone-gold trim (was faction blue)
        else Theme.set(Theme.frame, 0.55) end           -- idle: dimmer trim (icon dim shows unusable)
        local readySig = usable and item and item.activeAbility and item.activeAbility.unlock
        love.graphics.setLineWidth((armed or readySig) and 2 or 1)
        love.graphics.rectangle("line", sx, sy, sw, sh, 5, 5)
        love.graphics.setLineWidth(1)
    end
end

-- The current unit's item-to-item relationships, as wires running behind its cards. Off turn the
-- whole grid dims, so the wires dim with it.
function CombatPanel:drawAdjacencyLinks()
    AdjacencyLinks.draw(self.view.itemOwner, function(i) return self:slotRect(i) end,
        { width = 3, alpha = self.view.isPartyTurn and 1 or 0.4 })
end

-- ---------------------------------------------------------------------------
-- Input  (mouse; keyboard/gamepad item arming is handled by the battle state)
-- ---------------------------------------------------------------------------

-- Returns the ability item under the hovered slot on a party turn, whether or not it can fire right
-- now (else nil). This is what a CLICK acts on: a blocked ability still has to be reachable, so the
-- state can refuse it out loud (Rain of Arrows with no bow beside it says why) instead of the click
-- vanishing into a slot that looks pressable. Deciding IF it may fire is the state's job, not the
-- panel's -- Combat.itemBlockReason is the one gate, and it lives there.
-- A Blink (moveBehavior) item qualifies too: activating it toggles teleport movement.
function CombatPanel:actionItemAt(px, py)
    if not self.view.isPartyTurn then return nil end
    local i = self:slotIndexAt(px, py)
    local item = i and (self.view.items or {})[i]
    if item and (item.activeAbility or item.moveBehavior) then return item, i end
    return nil
end

-- Returns the ability item under a slot that can actually be activated right now (else nil). The
-- narrower read, for HOVER: an ability that can't fire must not preview its timeline, matching its
-- grayed-out slot (the hover tooltip via itemAt still explains why). Clicks use actionItemAt above.
function CombatPanel:usableItemAt(px, py)
    local item, i = self:actionItemAt(px, py)
    -- Blink has no ability cost, so blockReason never gates it.
    if item and not self:blockReason(item) then return item, i end
    return nil
end

-- The inventory item under the cursor (any slot, regardless of usability / whose turn it is),
-- or nil. Drives the hover item tooltip, which details passive items and off-turn slots too --
-- unlike usableItemAt, which gates on a party turn + an active ability for arm/preview.
function CombatPanel:itemAt(px, py)
    local i = self:slotIndexAt(px, py)
    return i and (self.view.items or {})[i] or nil
end

-- The status instance whose turn-strip badge is under (px, py), or nil (drives the shared
-- status tooltip). Skips preview ghosts, which don't draw badges.
-- The wait under the cursor: the figure this card is showing, or nil. Returns the SHOWN wait rather
-- than the model's, so a tooltip read mid-hand-off quotes the same number the card beside it does
-- (see shownClock).
--
-- ACTING IS A QUESTION OF RANK, NOT OF THE NUMBER. Several bodies can sit at 0.0 at once -- a wave
-- that arrives together shares an initiative -- and only the first of them is taking a turn; the rest
-- have no ticks left to spend and are waiting on the tie-break, which sends the FASTER body first
-- (models/combat.lua's orderBy). Reading "acting now" off a zero told three cards in a row that they
-- were the one acting. So `acting` asks who holds the turn, and `ready` is the separate fact that a
-- body has run its wait down without being first.
function CombatPanel:initiativeAt(px, py)
    for _, e in ipairs(self:entryLayout()) do
        local y = e.y
        if not e.entry.preview and self.cardY[e.entry.unit] then y = self.cardY[e.entry.unit]
        elseif e.entry.preview and e.entry.ghostSlot then
            local slots = self.ghostY[e.entry.unit]
            y = (slots and slots[e.entry.ghostSlot]) or y
        end
        local rx, ry, rw, rh = self:initiativeRect(e.entry, e.x, e.w, y)
        if rx and px >= rx and px <= rx + rw and py >= ry and py <= ry + rh then
            local w = self:shownWait(e.entry.initiative)
            local preview = e.entry.preview or false
            return { wait = w, unit = e.entry.unit, preview = preview,
                     acting = (not preview) and e.entry.unit == self.view.current,
                     ready = (not preview) and w < 0.05 }
        end
    end
    return nil
end

function CombatPanel:statusAt(px, py)
    for _, e in ipairs(self:entryLayout()) do
        if not e.entry.preview then
            local y = self.cardY[e.entry.unit] or e.y -- the eased slot the card is actually drawn at
            for _, r in ipairs(self:statusBadgeRects(e.entry.unit, e.x, e.w, y)) do
                if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
                    return r.st
                end
            end
        end
    end
    return nil
end

-- The unit whose turn-strip entry is under the cursor (else nil). Hit-tests the eased slot the card is
-- drawn at, not the target layout, so hover tracks a card mid-slide.
function CombatPanel:unitAt(px, py)
    for _, e in ipairs(self:entryLayout()) do
        local y = (not e.entry.preview and self.cardY[e.entry.unit]) or e.y
        if px >= e.x and px <= e.x + e.w and py >= y and py <= y + e.h then
            return e.entry.unit
        end
    end
    return nil
end

-- Set the hovered item / unit (either may be nil), firing the callbacks only on a change.
function CombatPanel:setHover(item, i, unit)
    if i ~= self.hoverIndex then
        self.hoverIndex = i
        if self.onHoverItem then self.onHoverItem(item) end
    end
    if unit ~= self.hoverUnit then
        self.hoverUnit = unit
        if self.onHoverUnit then self.onHoverUnit(unit) end
    end
end

-- Returns true when the cursor is over the panel (so the state won't also move the map
-- cursor). Reports item hover (turn-order preview) and unit hover (board highlight).
function CombatPanel:mousemoved(x, y)
    if not self:contains(x, y) then
        self:setHover(nil, nil, nil)
        self.waitHover = false
        return false
    end
    local item, i = self:usableItemAt(x, y)
    self:setHover(item, i, self:unitAt(x, y))
    self.waitHover = self.view.isPartyTurn and self:overWait(x, y) or false
    return true
end

-- Returns true when the click was inside the panel (consumed).
function CombatPanel:mousepressed(x, y, button)
    if button ~= 1 or not self:contains(x, y) then return false end
    if self.view.isPartyTurn and self:overWait(x, y) then
        if self.onWait then self.onWait() end
        return true
    end
    -- Route the click on ANY ability slot, usable or not: the state arms it, or refuses it with a
    -- reason the player can read. A silently swallowed click on a slot that looks pressable is the
    -- bug this avoids.
    local item, i = self:actionItemAt(x, y)
    if item and self.onActivateItem then self.onActivateItem(item, i) end
    -- Missed the grid: a click on a turn-strip card is the mouse's way to ask about that BODY. The
    -- strip is where a foe is read from, so it is where the asking belongs; what an inspect shows is
    -- the state's business (today, an assayed foe's kit card).
    if not item and self.onInspectUnit then
        local unit = self:unitAt(x, y)
        if unit then self.onInspectUnit(unit) end
    end
    return true
end

-- Walk the turn strip by `n` entries (positive = toward later turns), clamped.
function CombatPanel:scrollBy(n)
    self.scroll = math.max(0, math.min(self.scroll + n, self:maxScroll()))
end

-- One screenful toward later turns, wrapping back to the acting unit at the far end. The gamepad
-- has a single spare button for the strip (the d-pad drives the board cursor), so it cycles
-- instead of paging both ways.
function CombatPanel:cyclePage()
    local max = self:maxScroll()
    if max == 0 then return end
    self.scroll = (self.scroll >= max) and 0 or math.min(self.scroll + self:visibleCount(), max)
end

-- Mouse wheel: walk the turn strip (dy > 0 = wheel up = later turns, since the strip is pinned
-- to "now" at the bottom and grows upward). The caller gates this on the cursor being over the
-- panel. Returns true when it consumed the event.
function CombatPanel:wheelmoved(_, dy)
    if dy == 0 or self:maxScroll() == 0 then return false end
    self:scrollBy(dy > 0 and SCROLL_STEP or -SCROLL_STEP)
    return true
end

return CombatPanel
